//
//  QueryHistorySidebarViewModel.swift
//  PostgresGUI
//

import Foundation
import SwiftData

@Observable
@MainActor
final class QueryHistorySidebarViewModel {
    private let appState: AppState
    private let modelContext: ModelContext
    private let historyService: QueryHistoryServiceProtocol

    var searchText: String = ""
    var entryToConfirmDelete: QueryHistoryEntry?
    var showClearAllConfirmation: Bool = false

    init(
        appState: AppState,
        modelContext: ModelContext,
        historyService: QueryHistoryServiceProtocol? = nil
    ) {
        self.appState = appState
        self.modelContext = modelContext
        self.historyService = historyService ?? QueryHistoryService(modelContext: modelContext)
    }

    /// Entries scoped to the active connection (if any), newest first, search-filtered.
    func filteredEntries() -> [QueryHistoryEntry] {
        let connectionId = appState.connection.currentConnection?.id
        let all = historyService.entries(connectionId: connectionId, databaseName: nil)
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { entry in
            entry.queryText.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Loads `entry.queryText` into the active editor tab, replacing its contents.
    func loadIntoActiveEditor(_ entry: QueryHistoryEntry, tabManager: TabManager) {
        appState.query.queryText = entry.queryText
        tabManager.updateActiveTab(
            connectionId: nil,
            databaseName: nil,
            queryText: entry.queryText,
            persistToStorage: true
        )
    }

    /// Opens `entry.queryText` in a new tab (inheriting connection/database from the active tab).
    func openInNewTab(_ entry: QueryHistoryEntry, tabManager: TabManager) {
        tabManager.createNewTab(inheritingFrom: tabManager.activeTab)
        tabManager.updateActiveTab(queryText: entry.queryText, persistToStorage: true)
        appState.query.queryText = entry.queryText
    }

    /// Persists `entry.queryText` as a new SavedQuery in the user's library.
    func saveAsSavedQuery(_ entry: QueryHistoryEntry) {
        let saved = SavedQuery(
            name: SavedQuery.generateName(from: entry.queryText),
            queryText: entry.queryText,
            connectionId: entry.connectionId,
            databaseName: entry.databaseName
        )
        modelContext.insert(saved)
        try? modelContext.save()
    }

    func confirmDelete(_ entry: QueryHistoryEntry) {
        entryToConfirmDelete = entry
    }

    func performDelete(_ entry: QueryHistoryEntry) {
        historyService.delete(entry)
        entryToConfirmDelete = nil
    }

    func clearAllForActiveConnection() {
        historyService.clearAll(connectionId: appState.connection.currentConnection?.id)
        showClearAllConfirmation = false
    }
}
