//
//  SQLIdentifierQuoting.swift
//  PostgresGUI
//
//  PostgreSQL folds unquoted identifiers to lowercase, so a table created
//  with `CREATE TABLE "Usuarios" (...)` only resolves when referenced as
//  `"Usuarios"`. The helpers here quote identifiers (and dotted qualifiers
//  like `schema.table`) only when needed, leaving lowercase-safe names
//  untouched.
//

import Foundation

enum SQLIdentifierQuoting {

    /// Postgres-reserved words that must be double-quoted to be used as
    /// identifiers. Curated, not exhaustive — we err on the side of leaving
    /// unfamiliar tokens unquoted, since false positives are noisier than
    /// false negatives in autocomplete.
    static let reservedWords: Set<String> = [
        "all", "analyse", "analyze", "and", "any", "array", "as", "asc",
        "asymmetric", "both", "case", "cast", "check", "collate", "column",
        "constraint", "create", "current_catalog", "current_date", "current_role",
        "current_time", "current_timestamp", "current_user", "default",
        "deferrable", "desc", "distinct", "do", "else", "end", "except", "false",
        "fetch", "for", "foreign", "from", "grant", "group", "having", "in",
        "initially", "intersect", "into", "lateral", "leading", "limit",
        "localtime", "localtimestamp", "not", "null", "offset", "on", "only",
        "or", "order", "placing", "primary", "references", "returning", "select",
        "session_user", "some", "symmetric", "table", "then", "to", "trailing",
        "true", "union", "unique", "user", "using", "variadic", "when", "where",
        "window", "with",
    ]

    /// Returns `identifier` wrapped in double quotes when Postgres would
    /// reject or rename the bare form. Otherwise returns it unchanged.
    static func quoteIfNeeded(_ identifier: String) -> String {
        guard !identifier.isEmpty else { return identifier }
        guard needsQuoting(identifier) else { return identifier }
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Quotes each `.`-separated component independently. Useful for
    /// `schema.table`-style display names produced by autocomplete.
    static func quoteQualified(_ qualified: String) -> String {
        qualified
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { quoteIfNeeded(String($0)) }
            .joined(separator: ".")
    }

    // MARK: - Internals

    static func needsQuoting(_ identifier: String) -> Bool {
        guard let first = identifier.unicodeScalars.first else { return false }
        if !isLeadingChar(first) { return true }
        for scalar in identifier.unicodeScalars.dropFirst() {
            if !isBodyChar(scalar) { return true }
        }
        if reservedWords.contains(identifier.lowercased()) { return true }
        return false
    }

    /// `a-z` or `_` only — uppercase counts as "needs quoting" because Postgres
    /// folds unquoted identifiers to lowercase.
    private static func isLeadingChar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 0x61 && value <= 0x7A)  // a-z
            || value == 0x5F                       // _
    }

    /// Body char: `a-z`, `0-9`, `_`, `$`. (No uppercase, no `-`, no non-ASCII.)
    private static func isBodyChar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 0x61 && value <= 0x7A)  // a-z
            || (value >= 0x30 && value <= 0x39)  // 0-9
            || value == 0x5F                       // _
            || value == 0x24                       // $
    }
}
