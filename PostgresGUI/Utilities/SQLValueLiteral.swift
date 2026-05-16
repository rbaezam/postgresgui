//
//  SQLValueLiteral.swift
//  PostgresGUI
//
//  Centralized SQL string-literal quoting. Mirrors the single-quote
//  doubling pattern already used in row-mutation paths. Intended for
//  textual cell values pulled from query results, not for binary or
//  user-typed input — the parameterized-binding path is preferred but
//  not yet wired everywhere (tracked as tech debt).
//

import Foundation

enum SQLValueLiteral {
    /// Quote a string as a SQL literal, escaping any embedded single
    /// quotes. `O'Brien` → `'O''Brien'`. Empty string → `''`.
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }
}
