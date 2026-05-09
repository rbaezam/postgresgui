//
//  SQLIdentifierQuotingTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("SQLIdentifierQuoting")
struct SQLIdentifierQuotingTests {

    // MARK: - quoteIfNeeded

    @Test func leavesLowercaseIdentifierUnquoted() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("usuarios") == "usuarios")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("user_preferences") == "user_preferences")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("col_1") == "col_1")
    }

    @Test func quotesIdentifierWithUppercase() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("Usuarios") == "\"Usuarios\"")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("USERS") == "\"USERS\"")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("camelCase") == "\"camelCase\"")
    }

    @Test func quotesIdentifierWithSpecialChars() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("mi-tabla") == "\"mi-tabla\"")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("with space") == "\"with space\"")
    }

    @Test func quotesIdentifierStartingWithDigit() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("1tabla") == "\"1tabla\"")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("9_lives") == "\"9_lives\"")
    }

    @Test func quotesReservedWord() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("order") == "\"order\"")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("user") == "\"user\"")
        #expect(SQLIdentifierQuoting.quoteIfNeeded("select") == "\"select\"")
    }

    @Test func reservedWordCheckIsCaseInsensitive() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("ORDER") == "\"ORDER\"")
    }

    @Test func escapesInternalDoubleQuotes() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("col\"name") == "\"col\"\"name\"")
    }

    @Test func leavesEmptyStringUnchanged() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("") == "")
    }

    @Test func keepsUnderscorePrefixUnquoted() {
        #expect(SQLIdentifierQuoting.quoteIfNeeded("_internal") == "_internal")
    }

    // MARK: - quoteQualified

    @Test func quoteQualifiedKeepsLowercaseDotted() {
        #expect(SQLIdentifierQuoting.quoteQualified("public.users") == "public.users")
    }

    @Test func quoteQualifiedQuotesEachPartIndependently() {
        #expect(SQLIdentifierQuoting.quoteQualified("analytics.Events") == "analytics.\"Events\"")
        #expect(SQLIdentifierQuoting.quoteQualified("My_Schema.My_Table") == "\"My_Schema\".\"My_Table\"")
    }

    @Test func quoteQualifiedHandlesSinglePart() {
        #expect(SQLIdentifierQuoting.quoteQualified("Usuarios") == "\"Usuarios\"")
        #expect(SQLIdentifierQuoting.quoteQualified("users") == "users")
    }
}
