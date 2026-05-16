//
//  PaletteRanker.swift
//  PostgresGUI
//
//  Simple deterministic scoring for the ⌘K command palette.
//  Pure & easy to unit-test. No fuzzy/transposition tricks — title
//  prefix / word prefix / substring is enough for the catalog sizes
//  we have today.
//

import Foundation

enum PaletteRanker {
    /// Returns matching items sorted by descending score. Items with
    /// score 0 are dropped. Empty query returns all items unchanged.
    static func filter(
        _ commands: [PaletteCommand],
        query: String
    ) -> [PaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return commands }

        let scored = commands.compactMap { command -> (PaletteCommand, Int)? in
            let s = score(command, query: trimmed)
            return s > 0 ? (command, s) : nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                // Within a score tier prefer shorter titles — a 5-char
                // match for "user" feels closer than a 13-char one.
                if lhs.0.title.count != rhs.0.title.count {
                    return lhs.0.title.count < rhs.0.title.count
                }
                if lhs.0.kind != rhs.0.kind { return lhs.0.kind < rhs.0.kind }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
            .map(\.0)
    }

    /// Score a single command against a query (0..100).
    static func score(_ command: PaletteCommand, query: String) -> Int {
        let q = query.lowercased()
        guard !q.isEmpty else { return 0 }

        let title = command.title.lowercased()
        let titleScore = scoreText(title, query: q)
        if titleScore >= 80 { return titleScore }

        // Subtitle hits get a smaller ceiling so a strong title match
        // always beats a subtitle hit at the same tier.
        let subtitleScore = command.subtitle
            .map { min(60, scoreText($0.lowercased(), query: q)) } ?? 0

        return max(titleScore, subtitleScore)
    }

    // MARK: - Private

    private static let tokenSeparators: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "._-/")
        return set
    }()

    /// 100 exact · 90 prefix · 80 word-prefix · 50 substring · 0 none.
    private static func scoreText(_ text: String, query: String) -> Int {
        if text == query { return 100 }
        if text.hasPrefix(query) { return 90 }

        let tokens = text.unicodeScalars
            .split(whereSeparator: { tokenSeparators.contains($0) })
            .map { String($0) }
        for token in tokens where token.hasPrefix(query) {
            return 80
        }

        if text.contains(query) { return 50 }
        return 0
    }
}
