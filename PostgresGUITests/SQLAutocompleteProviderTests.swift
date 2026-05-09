//
//  SQLAutocompleteProviderTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("SQLAutocompleteProvider")
struct SQLAutocompleteProviderTests {

    // MARK: - Fixtures

    private static func makeContext(
        text: String,
        cursorLocation: Int? = nil,
        schemas: [String] = ["public", "analytics"]
    ) -> SQLCompletionContext {
        let cursor = cursorLocation ?? text.utf16.count
        let users = TableInfo(
            name: "users",
            schema: "public",
            columnInfo: [
                ColumnInfo(name: "id", dataType: "uuid"),
                ColumnInfo(name: "email", dataType: "text"),
                ColumnInfo(name: "username", dataType: "text"),
            ]
        )
        let userPrefs = TableInfo(
            name: "user_preferences",
            schema: "public",
            columnInfo: [
                ColumnInfo(name: "user_id", dataType: "uuid"),
                ColumnInfo(name: "theme", dataType: "text"),
            ]
        )
        let events = TableInfo(
            name: "events",
            schema: "analytics",
            columnInfo: [
                ColumnInfo(name: "event_id", dataType: "uuid"),
                ColumnInfo(name: "occurred_at", dataType: "timestamp"),
            ]
        )
        return SQLCompletionContext(
            schemas: schemas,
            tables: [users, userPrefs, events],
            text: text,
            cursorLocation: cursor
        )
    }

    // MARK: - partialWordAtCursor

    @Test func detectsBareIdentifierUnderCursor() {
        let result = SQLAutocompleteProvider.partialWordAtCursor(
            text: "SELECT * FROM use",
            cursorLocation: 17
        )
        #expect(result?.word == "use")
        #expect(result?.range == NSRange(location: 14, length: 3))
    }

    @Test func detectsQualifiedIdentifierWithDot() {
        let result = SQLAutocompleteProvider.partialWordAtCursor(
            text: "SELECT users. FROM users",
            cursorLocation: 13
        )
        #expect(result?.word == "users.")
        #expect(result?.range == NSRange(location: 7, length: 6))
    }

    // MARK: - shouldAutoTrigger

    @Test func autoTriggersAfterTwoIdentifierChars() {
        #expect(SQLAutocompleteProvider.shouldAutoTrigger(text: "se", cursorLocation: 2))
        #expect(!SQLAutocompleteProvider.shouldAutoTrigger(text: "s", cursorLocation: 1))
    }

    @Test func autoTriggersImmediatelyAfterDot() {
        #expect(SQLAutocompleteProvider.shouldAutoTrigger(text: "users.", cursorLocation: 6))
    }

    @Test func doesNotAutoTriggerInsideStringLiteral() {
        let text = "SELECT 'he"
        #expect(!SQLAutocompleteProvider.shouldAutoTrigger(text: text, cursorLocation: text.utf16.count))
    }

    @Test func doesNotAutoTriggerInsideLineComment() {
        let text = "-- pick a column"
        #expect(!SQLAutocompleteProvider.shouldAutoTrigger(text: text, cursorLocation: text.utf16.count))
    }

    // MARK: - completions: bare prefix

    @Test func completesTablesByPrefix() {
        let ctx = Self.makeContext(text: "SELECT * FROM use")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions.contains("users"))
        #expect(suggestions.contains("user_preferences"))
    }

    @Test func completesKeywordsForGenericPrefix() {
        let ctx = Self.makeContext(text: "sel")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions.contains("SELECT"))
    }

    @Test func tablesRankedBeforeKeywords() {
        // Both "users" (table) and no keyword starts with "use" — but if a
        // keyword *contains* "use" and a table also matches, the table wins.
        let ctx = Self.makeContext(text: "use")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        let usersIdx = suggestions.firstIndex(of: "users")
        #expect(usersIdx != nil)
        // No keyword starts with "use", so SELECT must come after via contains rank
        // — but in any case `users` (prefix match) should be first.
        if let idx = usersIdx {
            for keyword in suggestions[..<idx] {
                #expect(SQLAutocompleteProvider.keywords.contains(keyword) == false,
                        "Keyword \(keyword) ranked before table 'users'")
            }
        }
    }

    // MARK: - completions: table.column

    @Test func completesColumnsAfterTableDot() {
        let ctx = Self.makeContext(text: "SELECT users.")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions == ["id", "email", "username"])
    }

    @Test func filtersColumnsByPrefixAfterDot() {
        let ctx = Self.makeContext(text: "SELECT users.em")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions == ["email"])
    }

    @Test func columnLookupIsCaseInsensitiveOnTableName() {
        let ctx = Self.makeContext(text: "SELECT USERS.id")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions == ["id"])
    }

    // MARK: - completions: schema.table.column

    @Test func completesColumnsAfterSchemaTableDot() {
        let ctx = Self.makeContext(text: "SELECT analytics.events.")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions == ["event_id", "occurred_at"])
    }

    // MARK: - completions: schema.table

    @Test func completesTablesAfterSchemaDot() {
        let ctx = Self.makeContext(text: "SELECT * FROM analytics.")
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions == ["events"])
    }

    // MARK: - guards

    @Test func returnsEmptyInsideStringLiteral() {
        let text = "SELECT 'use"
        let ctx = Self.makeContext(text: text, cursorLocation: text.utf16.count)
        #expect(SQLAutocompleteProvider.completions(for: ctx).isEmpty)
    }

    @Test func returnsEmptyInsideLineComment() {
        let text = "-- use"
        let ctx = Self.makeContext(text: text, cursorLocation: text.utf16.count)
        #expect(SQLAutocompleteProvider.completions(for: ctx).isEmpty)
    }

    @Test func ignoresEscapedQuoteInString() {
        // The string is closed before cursor: ''  is an escaped quote.
        let text = "SELECT 'a''b' as x, use"
        let ctx = Self.makeContext(text: text, cursorLocation: text.utf16.count)
        let suggestions = SQLAutocompleteProvider.completions(for: ctx)
        #expect(suggestions.contains("users"))
    }
}
