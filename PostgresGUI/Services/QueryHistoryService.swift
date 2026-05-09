//
//  QueryHistoryService.swift
//  PostgresGUI
//

import Foundation
import SwiftData

@MainActor
final class QueryHistoryService: QueryHistoryServiceProtocol {
    private let modelContext: ModelContext
    private let userDefaults: UserDefaults
    private let maxEntries: Int

    init(
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard,
        maxEntries: Int = Constants.QueryHistory.maxEntries
    ) {
        self.modelContext = modelContext
        self.userDefaults = userDefaults
        self.maxEntries = maxEntries
        // Default the toggle to ON the first time the app runs.
        if userDefaults.object(forKey: Constants.UserDefaultsKeys.queryHistoryEnabled) == nil {
            userDefaults.set(true, forKey: Constants.UserDefaultsKeys.queryHistoryEnabled)
        }
    }

    // MARK: - Public API

    func record(
        queryText: String,
        connectionId: UUID?,
        databaseName: String?,
        result: QueryResult
    ) {
        guard isEnabled else { return }

        if let error = result.error, Self.isCancellation(error) {
            return
        }

        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = QueryHistoryEntry(
            queryText: queryText,
            connectionId: connectionId,
            databaseName: databaseName,
            executionTimeMs: result.executionTime * 1000.0,
            status: result.isSuccess ? .success : .error,
            errorMessage: result.error.map { Self.describe($0) },
            rowCount: result.isSuccess ? result.rows.count : nil
        )
        modelContext.insert(entry)

        purgeIfNeeded()
        try? modelContext.save()
    }

    func entries(connectionId: UUID?, databaseName: String?) -> [QueryHistoryEntry] {
        let descriptor = FetchDescriptor<QueryHistoryEntry>(
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { entry in
            if let connectionId, entry.connectionId != connectionId { return false }
            if let databaseName, entry.databaseName != databaseName { return false }
            return true
        }
    }

    func delete(_ entry: QueryHistoryEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    func clearAll(connectionId: UUID?) {
        let toDelete = entries(connectionId: connectionId, databaseName: nil)
        for entry in toDelete {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private var isEnabled: Bool {
        userDefaults.bool(forKey: Constants.UserDefaultsKeys.queryHistoryEnabled)
    }

    /// Keep the most-recent `maxEntries` rows; delete anything older.
    private func purgeIfNeeded() {
        var descriptor = FetchDescriptor<QueryHistoryEntry>(
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)]
        )
        descriptor.fetchLimit = maxEntries + 64
        guard let recent = try? modelContext.fetch(descriptor) else { return }
        guard recent.count > maxEntries else { return }
        for entry in recent[maxEntries..<recent.count] {
            modelContext.delete(entry)
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return true }
        // QueryService synthesises an NSError with this signature when a query is superseded.
        if nsError.domain == "QueryService", nsError.code == -1,
           let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
           message.localizedCaseInsensitiveContains("cancel") {
            return true
        }
        return false
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if let localized = nsError.userInfo[NSLocalizedDescriptionKey] as? String, !localized.isEmpty {
            return localized
        }
        return nsError.localizedDescription
    }
}
