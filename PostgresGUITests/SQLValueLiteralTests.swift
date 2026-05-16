//
//  SQLValueLiteralTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("SQLValueLiteral")
struct SQLValueLiteralTests {

    @Test func plainString() {
        #expect(SQLValueLiteral.quote("foo") == "'foo'")
        #expect(SQLValueLiteral.quote("hello world") == "'hello world'")
    }

    @Test func embeddedSingleQuote() {
        #expect(SQLValueLiteral.quote("O'Brien") == "'O''Brien'")
        #expect(SQLValueLiteral.quote("''") == "''''''")
    }

    @Test func empty() {
        #expect(SQLValueLiteral.quote("") == "''")
    }

    @Test func numericText() {
        // Quoted as a string; Postgres will coerce to the target column type.
        #expect(SQLValueLiteral.quote("42") == "'42'")
        #expect(SQLValueLiteral.quote("-1.5") == "'-1.5'")
    }

    @Test func newlinesAndUTF8() {
        let input = "line1\nline2 with é and 🎉"
        let expected = "'line1\nline2 with é and 🎉'"
        #expect(SQLValueLiteral.quote(input) == expected)
    }

    @Test func doubleQuotesUntouched() {
        // We only escape single quotes — double quotes pass through.
        #expect(SQLValueLiteral.quote("say \"hi\"") == "'say \"hi\"'")
    }
}
