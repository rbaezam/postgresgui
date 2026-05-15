//
//  RowDetailsPanel.swift
//  PostgresGUI
//

import SwiftUI

struct RowDetailsPanel: View {
    @Environment(AppState.self) private var appState

    enum ResolvedState: Equatable {
        case empty
        case multiple(count: Int)
        case single(TableRow)
    }

    static func resolveState(
        selectedRowIDs: Set<UUID>,
        rows: [TableRow]
    ) -> ResolvedState {
        switch selectedRowIDs.count {
        case 0:
            return .empty
        case 1:
            guard let id = selectedRowIDs.first,
                  let row = rows.first(where: { $0.id == id }) else {
                return .empty
            }
            return .single(row)
        default:
            return .multiple(count: selectedRowIDs.count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "list.bullet.rectangle")
                .foregroundStyle(.secondary)
            Text("Row Details")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch Self.resolveState(
            selectedRowIDs: appState.query.selectedRowIDs,
            rows: appState.query.queryResults
        ) {
        case .empty:
            ContentUnavailableView {
                Label("No Row Selected", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Select a row to see details.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .multiple(let count):
            ContentUnavailableView {
                Label("\(count) Rows Selected", systemImage: "rectangle.stack")
            } description: {
                Text("Select a single row to see details.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .single(let row):
            detailList(for: row)
        }
    }

    @ViewBuilder
    private func detailList(for row: TableRow) -> some View {
        let columnNames = displayColumnNames(for: row)
        let columnInfoByName = columnInfoLookup()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(columnNames.enumerated()), id: \.element) { index, columnName in
                    columnDetail(
                        name: columnName,
                        value: row.values[columnName] ?? nil,
                        info: columnInfoByName[columnName]
                    )
                    if index < columnNames.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func columnDetail(
        name: String,
        value: String?,
        info: ColumnInfo?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let info {
                    if info.isPrimaryKey {
                        Badge(text: "PK", color: .blue)
                    }
                    if info.isUnique {
                        Badge(text: "UNQ", color: .green)
                    }
                    if info.isForeignKey {
                        Badge(text: "FK", color: .orange)
                    }
                    if !info.isNullable {
                        Badge(text: "NOT NULL", color: .red)
                    }
                }
                Spacer()
                if let dataType = info?.dataType {
                    Text(dataType)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            valueView(for: value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func valueView(for value: String?) -> some View {
        if let value {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("NULL")
                .font(.system(.body, design: .monospaced))
                .italic()
                .foregroundStyle(.secondary)
        }
    }

    private func displayColumnNames(for row: TableRow) -> [String] {
        if let names = appState.query.queryColumnNames, !names.isEmpty {
            return names
        }
        return Array(row.values.keys).sorted()
    }

    private func columnInfoLookup() -> [String: ColumnInfo] {
        guard let columns = appState.connection.selectedTable?.columnInfo else {
            return [:]
        }
        var lookup: [String: ColumnInfo] = [:]
        for column in columns {
            lookup[column.name] = column
        }
        return lookup
    }
}
