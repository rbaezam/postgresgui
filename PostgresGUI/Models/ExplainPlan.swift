//
//  ExplainPlan.swift
//  PostgresGUI
//
//  Domain types for an EXPLAIN [ANALYZE] (FORMAT JSON) result.
//

import Foundation

/// Top-level wrapper returned by `EXPLAIN (FORMAT JSON) <query>`.
struct ExplainPlan: Equatable {
    let root: ExplainNode
    /// Planning time in milliseconds. Available when ANALYZE is on.
    let planningTimeMs: Double?
    /// Total execution time in milliseconds. Available when ANALYZE is on.
    let executionTimeMs: Double?
    /// True when the SQL was wrapped with ANALYZE (real timings) vs.
    /// estimated only (shown for mutations).
    let analyzed: Bool
}

/// A node in the EXPLAIN tree. Fields are sparse — different node types
/// supply different keys; we capture the most useful common fields for v1.
struct ExplainNode: Identifiable, Equatable {
    let id: UUID
    let nodeType: String

    /// The relation (table) this node operates on, if any.
    let relationName: String?
    let alias: String?
    let indexName: String?
    let schema: String?

    /// Planner estimates.
    let startupCost: Double?
    let totalCost: Double?
    let planRows: Int?
    let planWidth: Int?

    /// Runtime stats — only present when ANALYZE is on.
    let actualStartupTimeMs: Double?
    let actualTotalTimeMs: Double?
    let actualRows: Int?
    let actualLoops: Int?

    /// Common predicate fields.
    let filter: String?
    let rowsRemovedByFilter: Int?
    let joinType: String?
    let hashCondition: String?
    let indexCondition: String?
    let sortKey: [String]?
    let sortMethod: String?

    /// Children (Postgres calls them "Plans").
    let children: [ExplainNode]
}

extension ExplainNode {
    /// Time spent in this node *only*, excluding nested children.
    /// Useful to colour nodes by their own contribution rather than the
    /// cumulative tree time.
    var selfActualTimeMs: Double? {
        guard let total = actualTotalTimeMs else { return nil }
        let childrenTime = children.reduce(0.0) { acc, child in
            // EXPLAIN ANALYZE reports per-loop times, so multiply by loops.
            let perLoop = child.actualTotalTimeMs ?? 0
            let loops = Double(child.actualLoops ?? 1)
            return acc + perLoop * loops
        }
        let scaled = total * Double(actualLoops ?? 1)
        return max(0, scaled - childrenTime)
    }
}
