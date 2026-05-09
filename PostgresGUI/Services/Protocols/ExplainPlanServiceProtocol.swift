//
//  ExplainPlanServiceProtocol.swift
//  PostgresGUI
//

import Foundation

/// Result returned to the UI when explaining a query.
struct ExplainPlanResult {
    let plan: ExplainPlan
    /// True when ANALYZE was applied (real timings). False when the SQL was
    /// a mutation and we ran a plan-only EXPLAIN to avoid side effects.
    let analyzed: Bool
    /// The exact SQL we sent to Postgres (for diagnostic display).
    let executedSQL: String
}

@MainActor
protocol ExplainPlanServiceProtocol {
    /// Runs EXPLAIN against the given user SQL and returns the parsed plan.
    /// For mutations (UPDATE/INSERT/DELETE/CREATE/DROP/ALTER), ANALYZE is
    /// disabled so the underlying statement isn't executed.
    func explain(sql: String) async throws -> ExplainPlanResult
}
