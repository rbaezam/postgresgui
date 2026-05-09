//
//  QueryHistoryEntry.swift
//  PostgresGUI
//

import Foundation
import SwiftData

@Model
final class QueryHistoryEntry: Identifiable {
    var id: UUID
    var queryText: String
    var connectionId: UUID?
    var databaseName: String?
    var executedAt: Date
    var executionTimeMs: Double
    var statusRaw: String
    var errorMessage: String?
    var rowCount: Int?

    init(
        id: UUID = UUID(),
        queryText: String,
        connectionId: UUID? = nil,
        databaseName: String? = nil,
        executedAt: Date = Date(),
        executionTimeMs: Double,
        status: QueryHistoryStatus,
        errorMessage: String? = nil,
        rowCount: Int? = nil
    ) {
        self.id = id
        self.queryText = queryText
        self.connectionId = connectionId
        self.databaseName = databaseName
        self.executedAt = executedAt
        self.executionTimeMs = executionTimeMs
        self.statusRaw = status.rawValue
        self.errorMessage = errorMessage
        self.rowCount = rowCount
    }
}

enum QueryHistoryStatus: String {
    case success
    case error
}

extension QueryHistoryEntry {
    var status: QueryHistoryStatus {
        QueryHistoryStatus(rawValue: statusRaw) ?? .success
    }

    /// Single-line preview, trimmed and truncated for sidebar rows.
    var previewLine: String {
        let firstLine = queryText
            .split(whereSeparator: { $0.isNewline })
            .first
            .map(String.init) ?? queryText
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? queryText.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }
}
