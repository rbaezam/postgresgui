//
//  JSONFormatterTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("JSONFormatter")
struct JSONFormatterTests {

    @Test func prettyPrintsSimpleObject() {
        let pretty = JSONFormatter.prettyPrintObjectOrArray(#"{"a":1,"b":"x"}"#)
        #expect(pretty != nil)
        // Pretty-printed output has newlines and indentation
        #expect(pretty?.contains("\n") == true)
        // sortedKeys: a comes before b
        let aIndex = pretty?.range(of: "\"a\"")?.lowerBound
        let bIndex = pretty?.range(of: "\"b\"")?.lowerBound
        if let a = aIndex, let b = bIndex {
            #expect(a < b)
        } else {
            Issue.record("Expected both keys in output")
        }
    }

    @Test func prettyPrintsArray() {
        let pretty = JSONFormatter.prettyPrintObjectOrArray("[1, 2, 3]")
        #expect(pretty != nil)
        #expect(pretty?.contains("\n") == true)
    }

    @Test func prettyPrintsNestedStructure() {
        let pretty = JSONFormatter.prettyPrintObjectOrArray(
            #"{"items":[{"id":1},{"id":2}],"count":2}"#
        )
        #expect(pretty != nil)
        #expect(pretty?.contains("items") == true)
        #expect(pretty?.contains("count") == true)
    }

    @Test func returnsNilForScalarString() {
        // JSON strings (with quotes) are valid JSON but we only pretty-print
        // objects/arrays — raw is the faithful display.
        #expect(JSONFormatter.prettyPrintObjectOrArray("\"hello\"") == nil)
    }

    @Test func returnsNilForScalarNumber() {
        #expect(JSONFormatter.prettyPrintObjectOrArray("42") == nil)
        #expect(JSONFormatter.prettyPrintObjectOrArray("3.14") == nil)
    }

    @Test func returnsNilForScalarBool() {
        #expect(JSONFormatter.prettyPrintObjectOrArray("true") == nil)
        #expect(JSONFormatter.prettyPrintObjectOrArray("false") == nil)
    }

    @Test func returnsNilForMalformedJSON() {
        #expect(JSONFormatter.prettyPrintObjectOrArray("{not valid") == nil)
        #expect(JSONFormatter.prettyPrintObjectOrArray("plain text") == nil)
        #expect(JSONFormatter.prettyPrintObjectOrArray("") == nil)
    }

    @Test func returnsNilForOversizedInput() {
        // Build a string larger than 256KB
        let bigBlob = String(repeating: "a", count: JSONFormatter.maxPrettyPrintBytes + 1)
        let bigJSON = "{\"k\":\"\(bigBlob)\"}"
        #expect(JSONFormatter.prettyPrintObjectOrArray(bigJSON) == nil)
    }

    @Test func displayReturnsPrettyWhenJSON() {
        let raw = #"{"a":1}"#
        let display = JSONFormatter.display(raw)
        #expect(display.contains("\n"))
        #expect(display != raw)
    }

    @Test func displayReturnsRawWhenNotJSON() {
        let raw = "just some text"
        #expect(JSONFormatter.display(raw) == raw)
    }
}
