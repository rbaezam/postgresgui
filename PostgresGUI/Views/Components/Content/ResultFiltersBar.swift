//
//  ResultFiltersBar.swift
//  PostgresGUI
//
//  Thin horizontal chip strip above the query results, showing the
//  currently active equality filters. Hidden when there are no filters.
//  Removing a chip re-runs the table browse with the remaining filters.
//

import SwiftUI

struct ResultFiltersBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.query.resultFilters.isEmpty {
            content
        }
    }

    private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                ForEach(appState.query.resultFilters) { filter in
                    chip(for: filter)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func chip(for filter: ResultFilter) -> some View {
        HStack(spacing: 4) {
            Text(filter.column)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("=")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text(filter.value)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200)
            Button {
                remove(filter)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove filter")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private func remove(_ filter: ResultFilter) {
        guard let table = appState.connection.selectedTable else { return }
        let remaining = appState.query.resultFilters.filter { $0.id != filter.id }
        appState.requestTableQuery(for: table, filters: remaining)
    }
}
