//
//  ExplainPlanServiceTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("ExplainPlanService")
struct ExplainPlanServiceTests {

    // MARK: - Pure SQL building

    @Test func buildsExplainWithAnalyzeForReads() {
        let sql = ExplainPlanService.buildExplainSQL(
            userSQL: "SELECT * FROM users",
            analyze: true
        )
        #expect(sql.hasPrefix("EXPLAIN ("))
        #expect(sql.contains("ANALYZE"))
        #expect(sql.contains("BUFFERS"))
        #expect(sql.contains("FORMAT JSON"))
        #expect(sql.contains("VERBOSE"))
        #expect(sql.hasSuffix(" SELECT * FROM users"))
    }

    @Test func buildsExplainWithoutAnalyzeForMutations() {
        let sql = ExplainPlanService.buildExplainSQL(
            userSQL: "UPDATE users SET active = true",
            analyze: false
        )
        #expect(sql.contains("FORMAT JSON"))
        #expect(sql.contains("VERBOSE"))
        #expect(!sql.contains("ANALYZE"))
        #expect(!sql.contains("BUFFERS"))
        #expect(sql.hasSuffix(" UPDATE users SET active = true"))
    }

    @Test func stripsTrailingSemicolons() {
        #expect(ExplainPlanService.stripTrailingSemicolon("SELECT 1;") == "SELECT 1")
        #expect(ExplainPlanService.stripTrailingSemicolon("SELECT 1;;;  ") == "SELECT 1")
        #expect(ExplainPlanService.stripTrailingSemicolon("SELECT 1") == "SELECT 1")
    }

    // MARK: - Service behaviour

    @MainActor
    @Test func explainSelectAppliesAnalyze() async throws {
        let mock = ExplainMockDatabaseService()
        mock.queryResult = (
            [TableRow(values: ["QUERY PLAN": Self.simpleSelectJSON])],
            ["QUERY PLAN"]
        )
        let service = ExplainPlanService(databaseService: mock)

        let result = try await service.explain(sql: "SELECT * FROM users")

        #expect(result.analyzed == true)
        #expect(mock.lastSQL?.contains("ANALYZE") == true)
        #expect(result.plan.root.nodeType == "Seq Scan")
        #expect(result.plan.executionTimeMs == 5.456)
    }

    @MainActor
    @Test func explainUpdateSkipsAnalyze() async throws {
        let mock = ExplainMockDatabaseService()
        mock.queryResult = (
            [TableRow(values: ["QUERY PLAN": Self.plannedOnlyJSON])],
            ["QUERY PLAN"]
        )
        let service = ExplainPlanService(databaseService: mock)

        let result = try await service.explain(sql: "UPDATE users SET active = true")

        #expect(result.analyzed == false)
        #expect(mock.lastSQL?.contains("ANALYZE") == false)
        #expect(result.plan.root.nodeType == "Seq Scan")
        #expect(result.plan.executionTimeMs == nil)
    }

    @MainActor
    @Test func emptySQLThrows() async {
        let mock = ExplainMockDatabaseService()
        let service = ExplainPlanService(databaseService: mock)
        await #expect(throws: ExplainPlanServiceError.self) {
            _ = try await service.explain(sql: "   \n  ")
        }
    }

    @MainActor
    @Test func missingPlanColumnThrows() async {
        let mock = ExplainMockDatabaseService()
        mock.queryResult = ([], [])
        let service = ExplainPlanService(databaseService: mock)
        await #expect(throws: ExplainPlanServiceError.self) {
            _ = try await service.explain(sql: "SELECT 1")
        }
    }

    @MainActor
    @Test func wrapsParseErrors() async {
        let mock = ExplainMockDatabaseService()
        mock.queryResult = (
            [TableRow(values: ["QUERY PLAN": "not json {{{ "])],
            ["QUERY PLAN"]
        )
        let service = ExplainPlanService(databaseService: mock)
        await #expect(throws: ExplainPlanServiceError.self) {
            _ = try await service.explain(sql: "SELECT 1")
        }
    }

    // MARK: - Fixtures

    private static let simpleSelectJSON = #"""
    [{"Plan": {"Node Type": "Seq Scan", "Relation Name": "users", "Actual Total Time": 5.123, "Actual Rows": 10000, "Actual Loops": 1}, "Planning Time": 0.234, "Execution Time": 5.456}]
    """#

    private static let plannedOnlyJSON = #"""
    [{"Plan": {"Node Type": "Seq Scan", "Relation Name": "users", "Total Cost": 234.0, "Plan Rows": 10000}}]
    """#
}

// MARK: - Mock

@MainActor
private final class ExplainMockDatabaseService: DatabaseServiceProtocol {
    var isConnected: Bool = true
    var connectedDatabase: String? = "test"
    var queryResult: ([TableRow], [String]) = ([], [])
    var lastSQL: String?

    func connect(host: String, port: Int, username: String, password: String, database: String, sslMode: SSLMode) async throws {}
    func disconnect() async {}
    func shutdown() async {}
    func interruptInFlightTableBrowseLoadForSupersession() async {}
    func fetchDatabases() async throws -> [DatabaseInfo] { [] }
    func createDatabase(name: String) async throws {}
    func deleteDatabase(name: String) async throws {}
    func fetchTables(database: String) async throws -> [TableInfo] { [] }
    func fetchSchemas(database: String) async throws -> [String] { [] }
    func deleteTable(schema: String, table: String) async throws {}
    func truncateTable(schema: String, table: String) async throws {}
    func generateDDL(schema: String, table: String) async throws -> String { "" }
    func fetchAllTableData(schema: String, table: String) async throws -> ([TableRow], [String]) { ([], []) }

    func executeQuery(_ sql: String) async throws -> ([TableRow], [String]) {
        lastSQL = sql
        return queryResult
    }

    func executeDisplayQuery(_ sql: String) async throws -> ([TableRow], [String]) {
        lastSQL = sql
        return queryResult
    }

    func deleteRows(schema: String, table: String, primaryKeyColumns: [String], rows: [TableRow]) async throws {}
    func updateRow(schema: String, table: String, primaryKeyColumns: [String], originalRow: TableRow, updatedValues: [String: RowEditValue]) async throws {}
    func fetchPrimaryKeyColumns(schema: String, table: String) async throws -> [String] { [] }
    func fetchColumnInfo(schema: String, table: String) async throws -> [ColumnInfo] { [] }
}
