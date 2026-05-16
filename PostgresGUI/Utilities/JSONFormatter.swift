//
//  JSONFormatter.swift
//  PostgresGUI
//

import Foundation

enum JSONFormatter {
    /// Hard cap to keep pretty-printing off the main thread's hot path.
    /// Values longer than this byte length render raw.
    static let maxPrettyPrintBytes: Int = 256 * 1024

    /// Returns a pretty-printed representation when `value` parses as a
    /// JSON object or array, otherwise nil. Scalars (numbers, bare
    /// strings, booleans) return nil — they're already short and the
    /// raw text is the most faithful display.
    static func prettyPrintObjectOrArray(_ value: String) -> String? {
        guard value.utf8.count <= maxPrettyPrintBytes else { return nil }
        guard let data = value.data(using: .utf8) else { return nil }
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        guard parsed is [String: Any] || parsed is [Any] else { return nil }

        guard let pretty = try? JSONSerialization.data(
            withJSONObject: parsed,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }

        return String(data: pretty, encoding: .utf8)
    }

    /// Returns the pretty-printed version when available, else the
    /// untouched input.
    static func display(_ value: String) -> String {
        prettyPrintObjectOrArray(value) ?? value
    }
}
