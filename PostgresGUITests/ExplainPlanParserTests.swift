//
//  ExplainPlanParserTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("ExplainPlanParser")
struct ExplainPlanParserTests {

    // MARK: - Fixtures

    private static let simpleSelectAnalyzed = """
    [
      {
        "Plan": {
          "Node Type": "Seq Scan",
          "Relation Name": "users",
          "Alias": "u",
          "Schema": "public",
          "Startup Cost": 0.00,
          "Total Cost": 234.00,
          "Plan Rows": 10000,
          "Plan Width": 91,
          "Actual Startup Time": 0.027,
          "Actual Total Time": 5.123,
          "Actual Rows": 10000,
          "Actual Loops": 1,
          "Filter": "(active = true)",
          "Rows Removed by Filter": 5000
        },
        "Planning Time": 0.234,
        "Execution Time": 5.456
      }
    ]
    """

    private static let nestedJoinAnalyzed = """
    [
      {
        "Plan": {
          "Node Type": "Hash Join",
          "Join Type": "Inner",
          "Hash Cond": "(u.id = o.user_id)",
          "Actual Total Time": 12.5,
          "Actual Rows": 8000,
          "Actual Loops": 1,
          "Plans": [
            {
              "Node Type": "Seq Scan",
              "Relation Name": "users",
              "Alias": "u",
              "Actual Total Time": 1.2,
              "Actual Rows": 10000,
              "Actual Loops": 1
            },
            {
              "Node Type": "Hash",
              "Actual Total Time": 0.8,
              "Actual Rows": 8000,
              "Actual Loops": 1,
              "Plans": [
                {
                  "Node Type": "Seq Scan",
                  "Relation Name": "orders",
                  "Alias": "o",
                  "Filter": "(status = 'paid')",
                  "Rows Removed by Filter": 200,
                  "Actual Total Time": 0.78,
                  "Actual Rows": 8000,
                  "Actual Loops": 1
                }
              ]
            }
          ]
        },
        "Planning Time": 0.5,
        "Execution Time": 12.9
      }
    ]
    """

    private static let plannedOnly = """
    [
      {
        "Plan": {
          "Node Type": "Seq Scan",
          "Relation Name": "users",
          "Startup Cost": 0.00,
          "Total Cost": 234.00,
          "Plan Rows": 10000,
          "Plan Width": 91
        }
      }
    ]
    """

    // MARK: - Tests

    @Test func parsesSimpleAnalyzedPlan() throws {
        let plan = try ExplainPlanParser.parse(json: Self.simpleSelectAnalyzed, analyzed: true)
        #expect(plan.analyzed == true)
        #expect(plan.planningTimeMs == 0.234)
        #expect(plan.executionTimeMs == 5.456)

        let root = plan.root
        #expect(root.nodeType == "Seq Scan")
        #expect(root.relationName == "users")
        #expect(root.alias == "u")
        #expect(root.schema == "public")
        #expect(root.actualTotalTimeMs == 5.123)
        #expect(root.actualRows == 10000)
        #expect(root.actualLoops == 1)
        #expect(root.filter == "(active = true)")
        #expect(root.rowsRemovedByFilter == 5000)
        #expect(root.children.isEmpty)
    }

    @Test func parsesNestedTree() throws {
        let plan = try ExplainPlanParser.parse(json: Self.nestedJoinAnalyzed, analyzed: true)
        let root = plan.root
        #expect(root.nodeType == "Hash Join")
        #expect(root.joinType == "Inner")
        #expect(root.hashCondition == "(u.id = o.user_id)")
        #expect(root.children.count == 2)

        let firstChild = root.children[0]
        #expect(firstChild.nodeType == "Seq Scan")
        #expect(firstChild.relationName == "users")
        #expect(firstChild.children.isEmpty)

        let hashChild = root.children[1]
        #expect(hashChild.nodeType == "Hash")
        #expect(hashChild.children.count == 1)
        #expect(hashChild.children[0].nodeType == "Seq Scan")
        #expect(hashChild.children[0].relationName == "orders")
        #expect(hashChild.children[0].filter == "(status = 'paid')")
    }

    @Test func parsesPlanWithoutAnalyzeMetrics() throws {
        let plan = try ExplainPlanParser.parse(json: Self.plannedOnly, analyzed: false)
        #expect(plan.analyzed == false)
        #expect(plan.planningTimeMs == nil)
        #expect(plan.executionTimeMs == nil)
        #expect(plan.root.actualTotalTimeMs == nil)
        #expect(plan.root.actualRows == nil)
        #expect(plan.root.totalCost == 234.00)
        #expect(plan.root.planRows == 10000)
    }

    @Test func throwsOnInvalidJSON() {
        #expect(throws: ExplainPlanParserError.invalidJSON) {
            try ExplainPlanParser.parse(json: "not json at all {{{ ", analyzed: true)
        }
    }

    @Test func throwsOnEmptyArray() {
        #expect(throws: ExplainPlanParserError.emptyResult) {
            try ExplainPlanParser.parse(json: "[]", analyzed: true)
        }
    }

    @Test func throwsWhenRootPlanMissing() {
        #expect(throws: ExplainPlanParserError.missingRootPlan) {
            try ExplainPlanParser.parse(json: "[{}]", analyzed: true)
        }
    }

    @Test func unknownNodeFieldsAreIgnoredGracefully() throws {
        let json = """
        [
          {
            "Plan": {
              "Node Type": "BitmapOr",
              "Some Future Field": [1,2,3],
              "Plans": []
            }
          }
        ]
        """
        let plan = try ExplainPlanParser.parse(json: json, analyzed: false)
        #expect(plan.root.nodeType == "BitmapOr")
        #expect(plan.root.children.isEmpty)
    }

    // MARK: - selfActualTimeMs

    @Test func selfActualTimeSubtractsChildren() {
        // Hash Join total = 12.5 (per loop, 1 loop). Children combined: 1.2 + 0.8 = 2.0.
        // Self time should be ≈ 10.5 ms.
        let plan = try? ExplainPlanParser.parse(json: Self.nestedJoinAnalyzed, analyzed: true)
        let root = try! #require(plan?.root)
        let selfMs = root.selfActualTimeMs ?? 0
        #expect(abs(selfMs - 10.5) < 0.001)
    }
}
