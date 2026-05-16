//
//  CommandPaletteView.swift
//  PostgresGUI
//
//  ⌘K Spotlight-style command palette. Catalog covers tables in the
//  current database, saved queries, and a handful of built-in actions.
//

import SwiftData
import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showRowInspector") private var showRowInspector: Bool = true

    @Query(sort: \SavedQuery.updatedAt, order: .reverse) private var savedQueries: [SavedQuery]

    @State private var queryText: String = ""
    @State private var highlightedID: String? = nil
    @FocusState private var searchFieldFocused: Bool

    private var commands: [PaletteCommand] {
        tableCommands() + savedQueryCommands() + actionCommands()
    }

    private var filteredCommands: [PaletteCommand] {
        PaletteRanker.filter(commands, query: queryText)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
            Divider()
            footerHint
        }
        .frame(width: 600, height: 480)
        .onAppear {
            searchFieldFocused = true
            updateHighlight()
        }
        .onChange(of: queryText) { _, _ in updateHighlight() }
    }

    // MARK: - Sections

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tables, queries, commands…", text: $queryText)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
                .onSubmit { runHighlighted() }
                .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
                .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                .onKeyPress(.escape) { dismiss(); return .handled }
        }
        .font(.system(size: 18))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var resultsList: some View {
        if filteredCommands.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text("Try a different search.")
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedCommands, id: \.0) { (kind, items) in
                            sectionHeader(kind)
                            ForEach(items) { command in
                                row(for: command)
                                    .id(command.id)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: highlightedID) { _, newValue in
                    if let id = newValue {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ kind: PaletteCommand.Kind) -> some View {
        Text(kind.sectionTitle)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func row(for command: PaletteCommand) -> some View {
        let isHighlighted = command.id == highlightedID
        return HStack(spacing: 10) {
            Image(systemName: command.systemImage)
                .frame(width: 18)
                .foregroundStyle(isHighlighted ? Color.white : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 13))
                    .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isHighlighted ? Color.white.opacity(0.8) : .secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHighlighted ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            execute(command)
        }
        .onHover { hovering in
            if hovering { highlightedID = command.id }
        }
    }

    private var footerHint: some View {
        HStack(spacing: 12) {
            Spacer()
            Label("↑↓", systemImage: "")
            Text("navigate")
            Text("·")
            Label("↵", systemImage: "")
            Text("run")
            Text("·")
            Label("esc", systemImage: "")
            Text("close")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Grouping

    private var groupedCommands: [(PaletteCommand.Kind, [PaletteCommand])] {
        var groups: [PaletteCommand.Kind: [PaletteCommand]] = [:]
        for command in filteredCommands {
            groups[command.kind, default: []].append(command)
        }
        return PaletteCommand.Kind.allCases.compactMap { kind in
            guard let items = groups[kind], !items.isEmpty else { return nil }
            return (kind, items)
        }
    }

    // MARK: - Highlight management

    private func updateHighlight() {
        if let firstID = filteredCommands.first?.id {
            highlightedID = firstID
        } else {
            highlightedID = nil
        }
    }

    private func moveHighlight(by delta: Int) {
        let items = filteredCommands
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex(where: { $0.id == highlightedID }) ?? 0
        let count = items.count
        let next = ((currentIndex + delta) % count + count) % count
        highlightedID = items[next].id
    }

    private func runHighlighted() {
        guard let highlightedID,
              let command = filteredCommands.first(where: { $0.id == highlightedID }) else {
            return
        }
        execute(command)
    }

    private func execute(_ command: PaletteCommand) {
        dismiss()
        // Defer one runloop tick so the sheet has time to close before
        // mutations cascade into the underlying views.
        DispatchQueue.main.async {
            command.perform()
        }
    }

    // MARK: - Catalog builders

    private func tableCommands() -> [PaletteCommand] {
        appState.connection.tables.map { table in
            PaletteCommand(
                id: "table:\(table.id)",
                kind: .table,
                title: table.name,
                subtitle: table.schema,
                systemImage: "tablecells",
                perform: {
                    appState.requestTableQuery(for: table)
                }
            )
        }
    }

    private func savedQueryCommands() -> [PaletteCommand] {
        savedQueries.map { query in
            PaletteCommand(
                id: "savedQuery:\(query.id.uuidString)",
                kind: .savedQuery,
                title: query.name,
                subtitle: query.folder?.name,
                systemImage: "doc.text.magnifyingglass",
                perform: {
                    NotificationCenter.default.post(
                        name: .loadSavedQuery,
                        object: query.id
                    )
                }
            )
        }
    }

    private func actionCommands() -> [PaletteCommand] {
        [
            PaletteCommand(
                id: "action:newTab",
                kind: .action,
                title: "New Tab",
                subtitle: "⌘T",
                systemImage: "plus.square.on.square",
                perform: {
                    NotificationCenter.default.post(name: .createNewTab, object: nil)
                }
            ),
            PaletteCommand(
                id: "action:closeTab",
                kind: .action,
                title: "Close Tab",
                subtitle: "⌘W",
                systemImage: "xmark.square",
                perform: {
                    NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                }
            ),
            PaletteCommand(
                id: "action:toggleInspector",
                kind: .action,
                title: showRowInspector ? "Hide Row Inspector" : "Show Row Inspector",
                subtitle: nil,
                systemImage: "sidebar.right",
                perform: { showRowInspector.toggle() }
            ),
            PaletteCommand(
                id: "action:keyboardShortcuts",
                kind: .action,
                title: "Keyboard Shortcuts…",
                subtitle: nil,
                systemImage: "keyboard",
                perform: {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
            ),
            PaletteCommand(
                id: "action:help",
                kind: .action,
                title: "Postgresso Help",
                subtitle: nil,
                systemImage: "questionmark.circle",
                perform: {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
            ),
        ]
    }
}

extension PaletteCommand.Kind: CaseIterable {
    public static var allCases: [PaletteCommand.Kind] {
        [.table, .savedQuery, .action]
    }
}
