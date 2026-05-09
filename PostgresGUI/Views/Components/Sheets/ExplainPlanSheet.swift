//
//  ExplainPlanSheet.swift
//  PostgresGUI
//

import SwiftUI

struct ExplainPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExplainPlanViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Query Plan")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Running EXPLAIN…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(alignment: .leading, spacing: 12) {
                Label("Could not explain query", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .loaded(let result):
            ExplainPlanContent(result: result)
        }
    }
}

// MARK: - Plan content

private struct ExplainPlanContent: View {
    let result: ExplainPlanResult

    /// Total observed time for heatmap normalisation.
    private var totalActualMs: Double {
        result.plan.executionTimeMs
            ?? result.plan.root.actualTotalTimeMs
            ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ExplainNodeRowsView(
                        node: result.plan.root,
                        depth: 0,
                        totalMs: totalActualMs,
                        analyzed: result.analyzed
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                if let planning = result.plan.planningTimeMs {
                    metric(label: "Planning", value: format(planning))
                }
                if let execution = result.plan.executionTimeMs {
                    metric(label: "Execution", value: format(execution))
                }
                if !result.analyzed {
                    Label("Plan only — ANALYZE skipped for mutations",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary).font(.caption)
            Text(value).font(.system(.body, design: .monospaced).bold())
        }
    }

    private func format(_ ms: Double) -> String {
        if ms < 1 { return String(format: "%.3f ms", ms) }
        if ms < 1000 { return String(format: "%.2f ms", ms) }
        return String(format: "%.2f s", ms / 1000)
    }
}

// MARK: - Recursive rows

private struct ExplainNodeRowsView: View {
    let node: ExplainNode
    let depth: Int
    let totalMs: Double
    let analyzed: Bool

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                disclosure
                rowBody
            }
            .padding(.leading, CGFloat(depth) * 16)

            if isExpanded {
                ForEach(node.children) { child in
                    ExplainNodeRowsView(
                        node: child,
                        depth: depth + 1,
                        totalMs: totalMs,
                        analyzed: analyzed
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var disclosure: some View {
        if node.children.isEmpty {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
                .padding(.top, 6)
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(node.nodeType)
                    .font(.system(.body, design: .monospaced).bold())
                if let table = relationLabel {
                    Text(table)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                metrics
            }
            ForEach(detailLines, id: \.self) { line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(heatmapColour)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var relationLabel: String? {
        switch (node.relationName, node.alias) {
        case (let rel?, let alias?) where alias != rel:
            return "on \(rel) (\(alias))"
        case (let rel?, _):
            return "on \(rel)"
        case (nil, _):
            return nil
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            if analyzed, let actualMs = node.actualTotalTimeMs {
                Text(formatMs(actualMs))
                    .font(.system(.caption, design: .monospaced).bold())
            }
            if let rows = analyzed ? node.actualRows : node.planRows {
                Text("\(rows) row\(rows == 1 ? "" : "s")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if analyzed, let loops = node.actualLoops, loops != 1 {
                Text("× \(loops) loops")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if !analyzed, let cost = node.totalCost {
                Text(String(format: "cost %.1f", cost))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailLines: [String] {
        var lines: [String] = []
        if let cond = node.indexCondition { lines.append("Index Cond: \(cond)") }
        if let cond = node.hashCondition { lines.append("Hash Cond: \(cond)") }
        if let filter = node.filter { lines.append("Filter: \(filter)") }
        if let removed = node.rowsRemovedByFilter, removed > 0 {
            lines.append("Rows Removed by Filter: \(removed)")
        }
        if let keys = node.sortKey, !keys.isEmpty {
            lines.append("Sort Key: \(keys.joined(separator: ", "))")
        }
        if let method = node.sortMethod {
            lines.append("Sort Method: \(method)")
        }
        if let join = node.joinType {
            lines.append("Join Type: \(join)")
        }
        return lines
    }

    /// Background tint proportional to this node's *self* time relative to
    /// the full query's execution time. Returns the system background when
    /// timings aren't available (e.g. plan-only mutations).
    private var heatmapColour: Color {
        guard analyzed,
              let selfMs = node.selfActualTimeMs,
              totalMs > 0
        else { return Color(NSColor.textBackgroundColor).opacity(0.4) }
        let ratio = min(1.0, max(0.0, selfMs / totalMs))
        // Map ratio onto a translucent red gradient.
        return Color.red.opacity(0.10 + 0.45 * ratio)
    }

    private func formatMs(_ ms: Double) -> String {
        if ms < 1 { return String(format: "%.3f ms", ms) }
        if ms < 1000 { return String(format: "%.2f ms", ms) }
        return String(format: "%.2f s", ms / 1000)
    }
}
