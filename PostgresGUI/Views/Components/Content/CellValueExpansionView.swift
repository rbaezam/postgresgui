//
//  CellValueExpansionView.swift
//  PostgresGUI
//

import AppKit
import SwiftUI

struct CellValueExpansionView: View {
    let columnName: String
    let value: String?
    let dataType: String?
    var onDone: () -> Void

    @State private var showCopiedFeedback: Bool = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    private var displayText: String {
        guard let value else { return "" }
        return JSONFormatter.display(value)
    }

    private var isNull: Bool { value == nil }
    private var isEmpty: Bool { value?.isEmpty == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(
            minWidth: 400, idealWidth: 520, maxWidth: 720,
            minHeight: 200, idealHeight: 360, maxHeight: 640
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(columnName)
                .font(.headline)
            if let dataType {
                Text(dataType)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if isNull {
            placeholder("NULL")
        } else if isEmpty {
            placeholder("(empty)")
        } else {
            ScrollView([.vertical, .horizontal]) {
                Text(displayText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .italic()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                copyValue()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    Text(showCopiedFeedback ? "Copied" : "Copy value")
                }
            }
            .disabled(isNull)

            Spacer()

            Button("Done") {
                onDone()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func copyValue() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value ?? "", forType: .string)

        copyFeedbackTask?.cancel()
        showCopiedFeedback = true
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            showCopiedFeedback = false
        }
    }
}
