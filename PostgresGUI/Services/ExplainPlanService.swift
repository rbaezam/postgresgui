//
//  ExplainPlanService.swift
//  PostgresGUI
//

import Foundation

enum ExplainPlanServiceError: Error, LocalizedError {
    case emptyQuery
    case noPlanReturned
    case parseFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "No SQL query to explain."
        case .noPlanReturned:
            return "Postgres returned no plan for this query."
        case .parseFailed(let underlying):
            return "Could not parse the EXPLAIN result: \(underlying.localizedDescription)"
        }
    }
}

@MainActor
final class ExplainPlanService: ExplainPlanServiceProtocol {
    private let databaseService: DatabaseServiceProtocol

    init(databaseService: DatabaseServiceProtocol) {
        self.databaseService = databaseService
    }

    func explain(sql: String) async throws -> ExplainPlanResult {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExplainPlanServiceError.emptyQuery }

        let queryType = QueryTypeDetector.detect(trimmed)
        let analyze = !queryType.isMutation
        let strippedSQL = Self.stripTrailingSemicolon(trimmed)
        let explainSQL = Self.buildExplainSQL(userSQL: strippedSQL, analyze: analyze)

        let (rows, columnNames) = try await databaseService.executeQuery(explainSQL)
        let json = try Self.extractPlanJSON(rows: rows, columnNames: columnNames)

        do {
            let plan = try ExplainPlanParser.parse(json: json, analyzed: analyze)
            return ExplainPlanResult(plan: plan, analyzed: analyze, executedSQL: explainSQL)
        } catch {
            throw ExplainPlanServiceError.parseFailed(underlying: error)
        }
    }

    // MARK: - SQL building

    /// Constructs `EXPLAIN (...) <userSQL>` with options that produce a
    /// rich JSON payload. ANALYZE/BUFFERS/TIMING are only enabled for
    /// non-mutating statements.
    nonisolated static func buildExplainSQL(userSQL: String, analyze: Bool) -> String {
        var options = ["FORMAT JSON", "VERBOSE"]
        if analyze {
            options.insert("ANALYZE", at: 0)
            options.append("BUFFERS")
            options.append("TIMING")
        }
        let opts = options.joined(separator: ", ")
        return "EXPLAIN (\(opts)) \(userSQL)"
    }

    nonisolated static func stripTrailingSemicolon(_ sql: String) -> String {
        var result = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix(";") {
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    // MARK: - Result handling

    /// EXPLAIN (FORMAT JSON) returns one row with a single column ("QUERY PLAN")
    /// whose value is the serialized JSON tree.
    private static func extractPlanJSON(rows: [TableRow], columnNames: [String]) throws -> String {
        guard let row = rows.first else { throw ExplainPlanServiceError.noPlanReturned }

        // Try the canonical column name first; fall back to whichever column
        // exists, since some clients/proxies normalise the casing.
        let candidates = ["QUERY PLAN", "query plan", "Query Plan"]
        for key in candidates {
            if let value = row.values[key], let unwrapped = value, !unwrapped.isEmpty {
                return unwrapped
            }
        }
        if let firstColumn = columnNames.first,
           let value = row.values[firstColumn],
           let unwrapped = value,
           !unwrapped.isEmpty {
            return unwrapped
        }
        throw ExplainPlanServiceError.noPlanReturned
    }
}
