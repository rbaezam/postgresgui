//
//  QueryEditorComponent.swift
//  PostgresGUI
//
//  Presentational component for the query editor.
//  Receives data and callbacks - does not access AppState directly.
//

import SwiftUI

struct QueryEditorComponent: View {
    // Data
    let isExecuting: Bool
    let statusMessage: String?
    let lastExecutedAt: Date?
    let displayedElapsedTime: TimeInterval

    // Bindings
    @Binding var queryText: String

    // Callbacks
    let onRunQuery: () -> Void
    let onCancelQuery: () -> Void
    var onExplainQuery: (() -> Void)?

    /// Optional closure providing the schema/tables snapshot used for SQL
    /// autocomplete. Read by SyntaxHighlightedEditor on demand.
    var completionsDataSource: (@MainActor () -> SQLCompletionDataSource)?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with execute/cancel button and stats
            HStack(spacing: 0) {
                // Always show Run Query button
                Button(action: onRunQuery) {
                    Label {
                        Text("Run Query")
                    } icon: {
                        Image(systemName: "play.circle.fill")
                    }
                }
                .buttonStyle(.glass)
                .clipShape(Capsule())
                .tint(.green)
                .keyboardShortcut(.return, modifiers: [.command])

                // Show Stop button only after 3s of execution
                if isExecuting && displayedElapsedTime > 3 {
                    Button(action: onCancelQuery) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.bordered)
                    .glassEffect(.regular.interactive())
                    .clipShape(Circle())
                    .tint(.red)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                if let onExplainQuery {
                    Button(action: onExplainQuery) {
                        Label {
                            Text("Explain")
                        } icon: {
                            Image(systemName: "wand.and.stars")
                        }
                    }
                    .buttonStyle(.glass)
                    .clipShape(Capsule())
                    .tint(.purple)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(isExecuting)
                    .help("Run EXPLAIN ANALYZE on the current query (⇧⌘E)")
                }

                Spacer()

                // Dynamic status display
                statusView
            }
            .padding(Constants.Spacing.small)
            .background(Color(NSColor.controlBackgroundColor))

            // Syntax highlighted editor
            SyntaxHighlightedEditor(
                text: $queryText,
                completionsDataSource: completionsDataSource
            )
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if isExecuting {
            HStack(spacing: 4) {
                Text(QueryState.formatElapsedTime(displayedElapsedTime))
                    .foregroundColor(.secondary)
                    .font(.system(size: Constants.FontSize.small, design: .monospaced))
            }
        } else if let statusMessage = statusMessage {
            Text(statusMessage)
                .foregroundColor(.secondary)
                .font(.system(size: Constants.FontSize.small))
                .lineLimit(1)
        } else if let lastExecutedAt = lastExecutedAt {
            Text("Last Executed: \(lastExecutedAt.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)
                .font(.system(size: Constants.FontSize.small))
        }
    }
}
