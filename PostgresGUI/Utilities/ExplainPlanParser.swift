//
//  ExplainPlanParser.swift
//  PostgresGUI
//
//  Parses `EXPLAIN (FORMAT JSON) ...` output into ExplainPlan/ExplainNode.
//
//  Postgres returns:
//    [
//      {
//        "Plan": { "Node Type": ..., "Plans": [ ... ], ... },
//        "Planning Time": 0.234,
//        "Execution Time": 1.234
//      }
//    ]
//
//  Keys use spaces and TitleCase, so we walk JSON manually rather than
//  relying on Codable + custom decoding strategies. This also keeps the
//  parser tolerant to fields we haven't modelled yet.
//

import Foundation

enum ExplainPlanParserError: Error, Equatable {
    case invalidJSON
    case emptyResult
    case missingRootPlan
}

enum ExplainPlanParser {

    /// Parses the JSON string returned by `EXPLAIN (FORMAT JSON)`.
    /// - Parameter analyzed: pass `true` if the SQL was wrapped with ANALYZE.
    static func parse(json: String, analyzed: Bool) throws -> ExplainPlan {
        guard let data = json.data(using: .utf8) else {
            throw ExplainPlanParserError.invalidJSON
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw ExplainPlanParserError.invalidJSON
        }
        return try parse(object: object, analyzed: analyzed)
    }

    /// Parses a Foundation JSON object (Array/Dictionary/etc).
    static func parse(object: Any, analyzed: Bool) throws -> ExplainPlan {
        guard let array = object as? [Any] else {
            throw ExplainPlanParserError.invalidJSON
        }
        guard let first = array.first as? [String: Any] else {
            throw ExplainPlanParserError.emptyResult
        }
        guard let planDict = first["Plan"] as? [String: Any] else {
            throw ExplainPlanParserError.missingRootPlan
        }
        let root = parseNode(planDict)
        let planning = first["Planning Time"] as? Double
        let execution = first["Execution Time"] as? Double
        return ExplainPlan(
            root: root,
            planningTimeMs: planning,
            executionTimeMs: execution,
            analyzed: analyzed
        )
    }

    // MARK: - Internals

    private static func parseNode(_ dict: [String: Any]) -> ExplainNode {
        let childrenDicts = (dict["Plans"] as? [[String: Any]]) ?? []
        let children = childrenDicts.map(parseNode)

        return ExplainNode(
            id: UUID(),
            nodeType: dict["Node Type"] as? String ?? "Unknown",
            relationName: dict["Relation Name"] as? String,
            alias: dict["Alias"] as? String,
            indexName: dict["Index Name"] as? String,
            schema: dict["Schema"] as? String,
            startupCost: doubleField(dict, "Startup Cost"),
            totalCost: doubleField(dict, "Total Cost"),
            planRows: intField(dict, "Plan Rows"),
            planWidth: intField(dict, "Plan Width"),
            actualStartupTimeMs: doubleField(dict, "Actual Startup Time"),
            actualTotalTimeMs: doubleField(dict, "Actual Total Time"),
            actualRows: intField(dict, "Actual Rows"),
            actualLoops: intField(dict, "Actual Loops"),
            filter: dict["Filter"] as? String,
            rowsRemovedByFilter: intField(dict, "Rows Removed by Filter"),
            joinType: dict["Join Type"] as? String,
            hashCondition: dict["Hash Cond"] as? String,
            indexCondition: dict["Index Cond"] as? String,
            sortKey: dict["Sort Key"] as? [String],
            sortMethod: dict["Sort Method"] as? String,
            children: children
        )
    }

    /// JSON numeric values may decode as Int or NSNumber — coerce to Double.
    private static func doubleField(_ dict: [String: Any], _ key: String) -> Double? {
        if let d = dict[key] as? Double { return d }
        if let n = dict[key] as? NSNumber { return n.doubleValue }
        if let i = dict[key] as? Int { return Double(i) }
        return nil
    }

    private static func intField(_ dict: [String: Any], _ key: String) -> Int? {
        if let i = dict[key] as? Int { return i }
        if let n = dict[key] as? NSNumber { return n.intValue }
        if let d = dict[key] as? Double { return Int(d) }
        return nil
    }
}
