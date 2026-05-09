//
//  SQLAutocompleteProvider.swift
//  PostgresGUI
//
//  Pure logic that turns the editor's text + cursor position into a list
//  of completion strings ranked for the macOS NSTextView completion popup.
//

import Foundation

/// Schema/table snapshot supplied by the host (typically read from AppState).
/// Decoupled from the editor so the provider stays testable in isolation.
struct SQLCompletionDataSource {
    let schemas: [String]
    let tables: [TableInfo]
}

/// Snapshot of everything the provider needs to compute completions.
struct SQLCompletionContext {
    let schemas: [String]
    let tables: [TableInfo]
    /// Full editor text.
    let text: String
    /// 0-based UTF-16 offset of the cursor (NSTextView native indexing).
    let cursorLocation: Int

    init(schemas: [String], tables: [TableInfo], text: String, cursorLocation: Int) {
        self.schemas = schemas
        self.tables = tables
        self.text = text
        self.cursorLocation = cursorLocation
    }

    init(dataSource: SQLCompletionDataSource, text: String, cursorLocation: Int) {
        self.init(
            schemas: dataSource.schemas,
            tables: dataSource.tables,
            text: text,
            cursorLocation: cursorLocation
        )
    }

    /// Convenience for tests.
    static let empty = SQLCompletionContext(schemas: [], tables: [], text: "", cursorLocation: 0)
}

enum SQLAutocompleteProvider {

    // MARK: - Keywords

    /// Curated keyword list, kept in sync with the syntax highlighter.
    static let keywords: [String] = [
        "SELECT", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER",
        "ON", "AS", "ORDER", "BY", "GROUP", "HAVING", "INSERT", "UPDATE", "DELETE",
        "CREATE", "ALTER", "DROP", "TABLE", "INDEX", "VIEW", "DATABASE", "SCHEMA",
        "UNION", "INTERSECT", "EXCEPT", "DISTINCT", "LIMIT", "OFFSET",
        "CASE", "WHEN", "THEN", "ELSE", "END",
        "EXISTS", "NULL", "NOT", "AND", "OR", "IN", "LIKE", "ILIKE", "BETWEEN", "IS",
        "CAST", "COALESCE", "NULLIF", "GREATEST", "LEAST",
        "EXTRACT", "DATE_PART", "NOW", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP",
        "TRUE", "FALSE",
        "INTEGER", "BIGINT", "SMALLINT", "DECIMAL", "NUMERIC", "REAL",
        "BOOLEAN", "CHAR", "VARCHAR", "TEXT", "BYTEA", "DATE", "TIME", "TIMESTAMP",
        "INTERVAL", "JSON", "JSONB", "UUID", "SERIAL", "BIGSERIAL",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "CHECK", "DEFAULT",
        "CONSTRAINT", "USING", "WITH", "RETURNING",
        "EXPLAIN", "ANALYZE", "BEGIN", "COMMIT", "ROLLBACK", "TRUNCATE",
    ]

    // MARK: - Public API

    /// Returns the partial word currently being typed at the cursor.
    /// The "word" extends to the left until a non-identifier (and non-`.`) char.
    /// Example for "SELECT * FROM use<cursor>": returns "use" with range [14,17).
    /// Example for "users.<cursor>": returns "users." with range [0,6).
    static func partialWordAtCursor(text: String, cursorLocation: Int)
        -> (word: String, range: NSRange)?
    {
        let utf16 = Array(text.utf16)
        guard cursorLocation >= 0, cursorLocation <= utf16.count else { return nil }
        var start = cursorLocation
        while start > 0 {
            let unit = utf16[start - 1]
            guard let scalar = Unicode.Scalar(unit), isIdentifierOrDotChar(scalar) else { break }
            start -= 1
        }
        let length = cursorLocation - start
        let slice = Array(utf16[start..<cursorLocation])
        let word = slice.withUnsafeBufferPointer { buffer -> String in
            guard let base = buffer.baseAddress else { return "" }
            return String(utf16CodeUnits: base, count: buffer.count)
        }
        return (word, NSRange(location: start, length: length))
    }

    /// True when auto-trigger should fire. Manual trigger (Esc) bypasses this.
    /// Rules:
    ///   • Inside a string literal or single-line comment → never trigger.
    ///   • Word ends with a `.` → trigger (column hints).
    ///   • Word length ≥ minIdentifierLength → trigger.
    static func shouldAutoTrigger(
        text: String,
        cursorLocation: Int,
        minIdentifierLength: Int = 2
    ) -> Bool {
        if isInsideStringOrComment(text: text, cursorLocation: cursorLocation) {
            return false
        }
        guard let (word, _) = partialWordAtCursor(text: text, cursorLocation: cursorLocation) else {
            return false
        }
        if word.hasSuffix(".") { return true }
        return word.count >= minIdentifierLength
    }

    /// Returns ranked completion strings for the given context.
    static func completions(for context: SQLCompletionContext) -> [String] {
        if isInsideStringOrComment(text: context.text, cursorLocation: context.cursorLocation) {
            return []
        }
        guard let partial = partialWordAtCursor(
            text: context.text,
            cursorLocation: context.cursorLocation
        ) else {
            return []
        }

        let parts = partial.word.split(separator: ".", omittingEmptySubsequences: false).map(String.init)

        switch parts.count {
        case 1:
            // No dot: tables + keywords matching the prefix.
            return rankedNoDot(prefix: parts[0], context: context)
        case 2:
            // `<table>.<colPrefix>` or `<schema>.<tablePrefix>`
            let qualifier = parts[0]
            let prefix = parts[1]
            // First try treating qualifier as a table (any schema, public preferred).
            let columns = rankedColumns(forTableNamed: qualifier, prefix: prefix, context: context)
            if !columns.isEmpty {
                return columns
            }
            // Otherwise treat qualifier as a schema and complete tables in that schema.
            return rankedTables(inSchema: qualifier, prefix: prefix, context: context)
        case 3:
            // `<schema>.<table>.<colPrefix>`
            let schema = parts[0]
            let table = parts[1]
            let prefix = parts[2]
            return rankedColumns(
                forTableNamed: table,
                schema: schema,
                prefix: prefix,
                context: context
            )
        default:
            return []
        }
    }

    // MARK: - Ranking helpers

    private static func rankedNoDot(prefix: String, context: SQLCompletionContext) -> [String] {
        let lowerPrefix = prefix.lowercased()

        // Table names — distinct, preferring schema-qualified when not in `public`.
        var tableCandidates: [String] = []
        var seen = Set<String>()
        for table in context.tables {
            let candidate = table.schema == "public" ? table.name : "\(table.schema).\(table.name)"
            if seen.insert(candidate).inserted {
                tableCandidates.append(candidate)
            }
            // Always offer the bare table name too (avoids surprising users).
            if table.schema != "public", seen.insert(table.name).inserted {
                tableCandidates.append(table.name)
            }
        }

        let tableMatches = rank(candidates: tableCandidates, prefix: lowerPrefix)
        let keywordMatches = rank(candidates: keywords, prefix: lowerPrefix)
        let schemaMatches = rank(candidates: context.schemas, prefix: lowerPrefix)

        // Tables and schemas before keywords; keep insertion order within each bucket.
        return uniqued(tableMatches + schemaMatches + keywordMatches)
    }

    private static func rankedColumns(
        forTableNamed name: String,
        schema: String? = nil,
        prefix: String,
        context: SQLCompletionContext
    ) -> [String] {
        let lowerName = name.lowercased()
        let candidateTables = context.tables.filter { table in
            guard table.name.lowercased() == lowerName else { return false }
            if let schema = schema {
                return table.schema.lowercased() == schema.lowercased()
            }
            return true
        }
        guard !candidateTables.isEmpty else { return [] }

        var seen = Set<String>()
        var columns: [String] = []
        for table in candidateTables {
            for column in table.columnInfo ?? [] {
                if seen.insert(column.name).inserted {
                    columns.append(column.name)
                }
            }
        }
        return rank(candidates: columns, prefix: prefix.lowercased())
    }

    private static func rankedTables(
        inSchema schema: String,
        prefix: String,
        context: SQLCompletionContext
    ) -> [String] {
        let lowerSchema = schema.lowercased()
        let names = context.tables
            .filter { $0.schema.lowercased() == lowerSchema }
            .map { $0.name }
        return rank(candidates: names, prefix: prefix.lowercased())
    }

    /// Splits `candidates` into prefix matches first, then contains, both
    /// case-insensitive; keeps original casing for display.
    private static func rank(candidates: [String], prefix: String) -> [String] {
        if prefix.isEmpty { return candidates }
        var prefixMatches: [String] = []
        var containsMatches: [String] = []
        for candidate in candidates {
            let lower = candidate.lowercased()
            if lower.hasPrefix(prefix) {
                prefixMatches.append(candidate)
            } else if lower.contains(prefix) {
                containsMatches.append(candidate)
            }
        }
        return prefixMatches + containsMatches
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    // MARK: - Lexical helpers

    /// Identifier chars: a-z, A-Z, 0-9, _. We also treat `.` as part of the
    /// "word" so we can detect qualifier prefixes like `users.` from one range.
    private static func isIdentifierOrDotChar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 0x30 && value <= 0x39)        // 0-9
            || (value >= 0x41 && value <= 0x5A)        // A-Z
            || (value >= 0x61 && value <= 0x7A)        // a-z
            || value == 0x5F                            // _
            || value == 0x2E                            // .
    }

    /// Walks the text up to `cursorLocation` and decides whether the cursor
    /// is inside a single-quoted literal or a single-line `--` comment.
    /// Multi-line comments `/* ... */` are not considered yet — keeping it
    /// simple; the rare false-positive is not worth the parser complexity.
    static func isInsideStringOrComment(text: String, cursorLocation: Int) -> Bool {
        let utf16 = Array(text.utf16)
        let upper = min(cursorLocation, utf16.count)
        var inString = false
        var inLineComment = false
        var index = 0
        while index < upper {
            let unit = utf16[index]
            if inLineComment {
                if unit == 0x000A /* \n */ { inLineComment = false }
                index += 1
                continue
            }
            if inString {
                if unit == 0x27 /* ' */ {
                    // Handle the '' escape inside literals.
                    if index + 1 < upper && utf16[index + 1] == 0x27 {
                        index += 2
                        continue
                    }
                    inString = false
                }
                index += 1
                continue
            }
            if unit == 0x27 /* ' */ {
                inString = true
                index += 1
                continue
            }
            if unit == 0x2D /* - */, index + 1 < upper, utf16[index + 1] == 0x2D {
                inLineComment = true
                index += 2
                continue
            }
            index += 1
        }
        return inString || inLineComment
    }
}
