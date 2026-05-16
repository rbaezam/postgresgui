//
//  ResultsHeaderBar.swift
//  PostgresGUI
//
//  Thin static header above the query results showing the selected
//  table identity. Hidden when there's no selected table (e.g. an
//  ad-hoc query against no specific table).
//

import SwiftUI

struct ResultsHeaderBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let table = appState.connection.selectedTable {
            content(for: table)
        }
    }

    private func content(for table: TableInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tablecells")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(table.schema)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(".")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(table.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer(minLength: 0)
            if appState.query.queryResults.count > 0 {
                Text("\(appState.query.queryResults.count) rows")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }
}
