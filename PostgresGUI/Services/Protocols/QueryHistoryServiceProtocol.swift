//
//  QueryHistoryServiceProtocol.swift
//  PostgresGUI
//

import Foundation

/// Persists query executions for the user's history.
@MainActor
protocol QueryHistoryServiceProtocol {
    /// Records the result of a query execution. Cancelled queries are ignored.
    /// Respects the user's "Save query history" setting; when disabled this is a no-op.
    func record(
        queryText: String,
        connectionId: UUID?,
        databaseName: String?,
        result: QueryResult
    )

    /// Returns history entries, newest first, optionally filtered by connection and database.
    func entries(connectionId: UUID?, databaseName: String?) -> [QueryHistoryEntry]

    /// Deletes a single entry.
    func delete(_ entry: QueryHistoryEntry)

    /// Deletes every entry. If `connectionId` is provided, only entries for that connection.
    func clearAll(connectionId: UUID?)
}
