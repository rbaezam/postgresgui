//
//  QueryHistorySidebarSection.swift
//  PostgresGUI
//

import SwiftData
import SwiftUI

struct QueryHistorySidebarSection: View {
    @Environment(AppState.self) private var appState
    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \QueryHistoryEntry.executedAt, order: .reverse)
    private var allEntries: [QueryHistoryEntry]

    @State private var viewModel: QueryHistorySidebarViewModel?

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel = viewModel {
                header(viewModel: viewModel)
                searchHeader(viewModel: viewModel)
                list(viewModel: viewModel)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = QueryHistorySidebarViewModel(
                    appState: appState,
                    modelContext: modelContext
                )
            }
        }
        .alert(
            "Delete this entry?",
            isPresented: Binding(
                get: { viewModel?.entryToConfirmDelete != nil },
                set: { newValue in
                    if !newValue { viewModel?.entryToConfirmDelete = nil }
                }
            ),
            presenting: viewModel?.entryToConfirmDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                viewModel?.performDelete(entry)
            }
            Button("Cancel", role: .cancel) {
                viewModel?.entryToConfirmDelete = nil
            }
        } message: { _ in
            Text("This removes the entry from your query history.")
        }
        .alert(
            "Clear query history?",
            isPresented: Binding(
                get: { viewModel?.showClearAllConfirmation ?? false },
                set: { newValue in viewModel?.showClearAllConfirmation = newValue }
            )
        ) {
            Button("Clear", role: .destructive) {
                viewModel?.clearAllForActiveConnection()
            }
            Button("Cancel", role: .cancel) {
                viewModel?.showClearAllConfirmation = false
            }
        } message: {
            Text("This removes every history entry for the active connection.")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(viewModel: QueryHistorySidebarViewModel) -> some View {
        HStack {
            Text("History")
                .font(.headline)

            Spacer()

            Menu {
                Button(role: .destructive) {
                    viewModel.showClearAllConfirmation = true
                } label: {
                    Label("Clear history", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
    }

    // MARK: - Search

    @ViewBuilder
    private func searchHeader(viewModel: QueryHistorySidebarViewModel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField(
                "Filter history",
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                )
            )
            .font(.system(size: 12))
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            Capsule().stroke(Color.secondary, lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    // MARK: - List

    @ViewBuilder
    private func list(viewModel: QueryHistorySidebarViewModel) -> some View {
        // `_ = allEntries` keeps the @Query subscription alive so SwiftData
        // re-renders this view whenever entries are inserted/deleted.
        let _ = allEntries
        let entries = viewModel.filteredEntries()

        List {
            if entries.isEmpty {
                Text(allEntries.isEmpty ? "No queries run yet" : "No matching entries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    historyRow(entry: entry, viewModel: viewModel)
                        .listRowSeparator(.visible)
                }
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
    }

    @ViewBuilder
    private func historyRow(
        entry: QueryHistoryEntry,
        viewModel: QueryHistorySidebarViewModel
    ) -> some View {
        let statusIcon = entry.status == .success ? "checkmark.circle.fill" : "xmark.octagon.fill"
        let statusColor: Color = entry.status == .success ? .green : .red

        Button {
            viewModel.loadIntoActiveEditor(entry, tabManager: tabManager)
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 10))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.previewLine)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 6) {
                        Text(Self.relativeFormatter.localizedString(for: entry.executedAt, relativeTo: Date()))
                        Text("·")
                        Text(Self.formatDuration(entry.executionTimeMs))
                        if let rowCount = entry.rowCount {
                            Text("·")
                            Text("\(rowCount) row\(rowCount == 1 ? "" : "s")")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.loadIntoActiveEditor(entry, tabManager: tabManager)
            } label: {
                Label("Open in editor", systemImage: "square.and.pencil")
            }
            Button {
                viewModel.openInNewTab(entry, tabManager: tabManager)
            } label: {
                Label("Open in new tab", systemImage: "plus.rectangle.on.rectangle")
            }
            Button {
                copyToPasteboard(entry.queryText)
            } label: {
                Label("Copy SQL", systemImage: "doc.on.doc")
            }
            Button {
                viewModel.saveAsSavedQuery(entry)
            } label: {
                Label("Save as saved query…", systemImage: "tray.and.arrow.down")
            }
            Divider()
            Button(role: .destructive) {
                viewModel.confirmDelete(entry)
            } label: {
                Label("Delete entry", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private static func formatDuration(_ ms: Double) -> String {
        if ms < 1 {
            return "<1 ms"
        }
        if ms < 1000 {
            return "\(Int(ms.rounded())) ms"
        }
        return String(format: "%.2f s", ms / 1000.0)
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
