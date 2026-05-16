//
//  ReadOnlyGate.swift
//  PostgresGUI
//
//  Decides whether a SQL block is safe to run on a read-only connection.
//  Uses an allowlist of safe verbs (fail-closed): unknown verbs are blocked.
//

import Foundation

enum ReadOnlyGate {
    /// Returns true if every non-empty statement in `sql` is read-safe.
    /// One mutation taints the whole block.
    static func isReadSafe(_ sql: String) -> Bool {
        let statements = SQLStatementSplitter.split(sql)
        if statements.isEmpty {
            // Empty or comment-only input — nothing to execute, treat as safe.
            return true
        }
        return statements.allSatisfy(isStatementReadSafe)
    }

    // MARK: - Private

    private static let safePrefixes: [String] = [
        "SELECT",
        "WITH",
        "EXPLAIN",
        "SHOW",
        "VALUES",
        "TABLE",
        "BEGIN",
        "COMMIT",
        "ROLLBACK",
        "SAVEPOINT",
        "RELEASE",
        "START",     // START TRANSACTION
        "END",       // END (synonym for COMMIT)
        "SET",
        "RESET"
    ]

    private static func isStatementReadSafe(_ statement: String) -> Bool {
        let normalized = stripLeadingNoise(statement)
        guard !normalized.isEmpty else { return true }
        let upper = normalized.uppercased()

        guard let firstWord = firstToken(upper) else { return false }

        // EXPLAIN may wrap a mutation when used with ANALYZE — strip the
        // EXPLAIN prefix (and its optional parenthesized options) and re-test
        // the remaining statement.
        if firstWord == "EXPLAIN" {
            let rest = stripExplainPrefix(normalized)
            if rest.isEmpty {
                // Bare "EXPLAIN" with no body — meaningless but harmless.
                return true
            }
            return isStatementReadSafe(rest)
        }

        return safePrefixes.contains(firstWord)
    }

    /// Strip leading whitespace and SQL comments (both `--` line comments
    /// and `/* */` block comments).
    private static func stripLeadingNoise(_ statement: String) -> String {
        var s = Substring(statement)
        while true {
            let trimmed = s.drop(while: { $0.isWhitespace })
            if trimmed.hasPrefix("--") {
                // Skip to end of line.
                if let newline = trimmed.firstIndex(of: "\n") {
                    s = trimmed[trimmed.index(after: newline)...]
                } else {
                    return ""
                }
                continue
            }
            if trimmed.hasPrefix("/*") {
                if let end = trimmed.range(of: "*/") {
                    s = trimmed[end.upperBound...]
                } else {
                    return ""
                }
                continue
            }
            return String(trimmed)
        }
    }

    /// Return the first keyword token (already uppercased input).
    /// Separators include whitespace, semicolons, and opening parens so that
    /// inputs like "BEGIN;" or "EXPLAIN(VERBOSE)..." resolve to "BEGIN"/"EXPLAIN".
    private static func firstToken(_ upper: String) -> String? {
        let token = upper.split(whereSeparator: {
            $0.isWhitespace || $0 == "(" || $0 == ";" || $0 == ","
        }).first
        return token.map(String.init)
    }

    /// Strip a leading EXPLAIN (with optional ANALYZE / VERBOSE / parenthesized
    /// options) and return the remainder. Pre: input starts with EXPLAIN.
    private static func stripExplainPrefix(_ statement: String) -> String {
        var s = Substring(statement)
        // Drop "EXPLAIN".
        s = s.drop(while: { !$0.isWhitespace && $0 != "(" })

        while true {
            s = s.drop(while: { $0.isWhitespace })

            // Parenthesized options block: EXPLAIN (ANALYZE, VERBOSE, FORMAT JSON) ...
            if s.first == "(" {
                guard let close = s.firstIndex(of: ")") else { return "" }
                s = s[s.index(after: close)...]
                continue
            }

            // Bare ANALYZE / VERBOSE modifiers (legacy syntax).
            let upper = s.uppercased()
            if upper.hasPrefix("ANALYZE") || upper.hasPrefix("ANALYSE") {
                s = s.dropFirst(7)
                continue
            }
            if upper.hasPrefix("VERBOSE") {
                s = s.dropFirst(7)
                continue
            }

            break
        }

        return String(s).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
