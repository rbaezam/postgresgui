//
//  QueryHistoryServiceTests.swift
//  PostgresGUITests
//
//  Unit tests for QueryHistoryService.
//

import Foundation
import SwiftData
import Testing
@testable import PostgresGUI

@Suite("QueryHistoryService")
@MainActor
struct QueryHistoryServiceTests {

    // MARK: - Helpers

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([QueryHistoryEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private static func makeDefaults() -> UserDefaults {
        let suite = "QueryHistoryServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private static func makeService(
        context: ModelContext,
        defaults: UserDefaults? = nil,
        maxEntries: Int = 500
    ) -> QueryHistoryService {
        QueryHistoryService(
            modelContext: context,
            userDefaults: defaults ?? Self.makeDefaults(),
            maxEntries: maxEntries
        )
    }

    private static func successResult(rowCount: Int = 1, executionTime: TimeInterval = 0.05) -> QueryResult {
        let rows = (0..<rowCount).map { _ in TableRow(values: ["x": "1"]) }
        return .success(rows: rows, columnNames: ["x"], executionTime: executionTime)
    }

    private static func failureResult(_ message: String = "boom") -> QueryResult {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        return .failure(error: error, executionTime: 0.02)
    }

    // MARK: - record

    @Test func recordsSuccessfulQuery() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)
        let connectionId = UUID()

        service.record(
            queryText: "select 1",
            connectionId: connectionId,
            databaseName: "postgres",
            result: Self.successResult(rowCount: 3, executionTime: 0.123)
        )

        let entries = service.entries(connectionId: nil, databaseName: nil)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.queryText == "select 1")
        #expect(entry.connectionId == connectionId)
        #expect(entry.databaseName == "postgres")
        #expect(entry.status == .success)
        #expect(entry.rowCount == 3)
        #expect(abs(entry.executionTimeMs - 123.0) < 0.001)
        #expect(entry.errorMessage == nil)
    }

    @Test func recordsFailedQueryWithErrorMessage() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)

        service.record(
            queryText: "select bad",
            connectionId: nil,
            databaseName: nil,
            result: Self.failureResult("syntax error")
        )

        let entries = service.entries(connectionId: nil, databaseName: nil)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.status == .error)
        #expect(entry.errorMessage == "syntax error")
        #expect(entry.rowCount == nil)
    }

    @Test func ignoresCancellationError() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)

        let cancelled = QueryResult.failure(error: CancellationError(), executionTime: 0.0)
        service.record(queryText: "select 1", connectionId: nil, databaseName: nil, result: cancelled)

        let supersededError = NSError(
            domain: "QueryService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Query was cancelled"]
        )
        let superseded = QueryResult.failure(error: supersededError, executionTime: 0.0)
        service.record(queryText: "select 2", connectionId: nil, databaseName: nil, result: superseded)

        #expect(service.entries(connectionId: nil, databaseName: nil).isEmpty)
    }

    @Test func ignoresEmptyQueryText() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)

        service.record(
            queryText: "   \n  \t",
            connectionId: nil,
            databaseName: nil,
            result: Self.successResult()
        )

        #expect(service.entries(connectionId: nil, databaseName: nil).isEmpty)
    }

    @Test func skipsRecordingWhenDisabled() throws {
        let context = try Self.makeContext()
        let defaults = Self.makeDefaults()
        defaults.set(false, forKey: Constants.UserDefaultsKeys.queryHistoryEnabled)
        let service = QueryHistoryService(modelContext: context, userDefaults: defaults)

        service.record(
            queryText: "select 1",
            connectionId: nil,
            databaseName: nil,
            result: Self.successResult()
        )

        #expect(service.entries(connectionId: nil, databaseName: nil).isEmpty)
    }

    // MARK: - filtering

    @Test func filtersByConnectionAndDatabase() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)
        let conn1 = UUID()
        let conn2 = UUID()

        service.record(queryText: "a", connectionId: conn1, databaseName: "alpha", result: Self.successResult())
        service.record(queryText: "b", connectionId: conn1, databaseName: "beta", result: Self.successResult())
        service.record(queryText: "c", connectionId: conn2, databaseName: "alpha", result: Self.successResult())

        #expect(service.entries(connectionId: conn1, databaseName: nil).count == 2)
        #expect(service.entries(connectionId: conn1, databaseName: "alpha").count == 1)
        #expect(service.entries(connectionId: conn2, databaseName: "beta").isEmpty)
        #expect(service.entries(connectionId: nil, databaseName: nil).count == 3)
    }

    @Test func entriesAreNewestFirst() async throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)

        for index in 0..<5 {
            service.record(
                queryText: "q\(index)",
                connectionId: nil,
                databaseName: nil,
                result: Self.successResult()
            )
            // Ensure executedAt timestamps are strictly ordered.
            try await Task.sleep(nanoseconds: 2_000_000)
        }

        let entries = service.entries(connectionId: nil, databaseName: nil)
        #expect(entries.map(\.queryText) == ["q4", "q3", "q2", "q1", "q0"])
    }

    // MARK: - cap / purge

    @Test func purgesOldestWhenOverCap() async throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context, maxEntries: 5)

        for index in 0..<10 {
            service.record(
                queryText: "q\(index)",
                connectionId: nil,
                databaseName: nil,
                result: Self.successResult()
            )
            try await Task.sleep(nanoseconds: 2_000_000)
        }

        let entries = service.entries(connectionId: nil, databaseName: nil)
        #expect(entries.count == 5)
        #expect(entries.map(\.queryText) == ["q9", "q8", "q7", "q6", "q5"])
    }

    // MARK: - delete / clearAll

    @Test func deleteRemovesSingleEntry() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)

        service.record(queryText: "a", connectionId: nil, databaseName: nil, result: Self.successResult())
        service.record(queryText: "b", connectionId: nil, databaseName: nil, result: Self.successResult())

        let entries = service.entries(connectionId: nil, databaseName: nil)
        let target = try #require(entries.first(where: { $0.queryText == "a" }))
        service.delete(target)

        let remaining = service.entries(connectionId: nil, databaseName: nil)
        #expect(remaining.count == 1)
        #expect(remaining.first?.queryText == "b")
    }

    @Test func clearAllRemovesAll() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)

        for index in 0..<3 {
            service.record(
                queryText: "q\(index)",
                connectionId: nil,
                databaseName: nil,
                result: Self.successResult()
            )
        }

        service.clearAll(connectionId: nil)
        #expect(service.entries(connectionId: nil, databaseName: nil).isEmpty)
    }

    @Test func clearAllScopedToConnection() throws {
        let context = try Self.makeContext()
        let service = Self.makeService(context: context)
        let conn1 = UUID()
        let conn2 = UUID()

        service.record(queryText: "a", connectionId: conn1, databaseName: nil, result: Self.successResult())
        service.record(queryText: "b", connectionId: conn2, databaseName: nil, result: Self.successResult())

        service.clearAll(connectionId: conn1)

        let remaining = service.entries(connectionId: nil, databaseName: nil)
        #expect(remaining.count == 1)
        #expect(remaining.first?.connectionId == conn2)
    }
}
