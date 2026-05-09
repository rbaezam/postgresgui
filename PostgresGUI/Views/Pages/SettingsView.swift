//
//  SettingsView.swift
//  PostgresGUI
//
//  Application settings view.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(Constants.UserDefaultsKeys.queryResultsDateFormat)
    private var dateFormatRawValue = QueryResultsDateFormat.iso8601.rawValue

    @AppStorage(Constants.UserDefaultsKeys.queryHistoryEnabled)
    private var queryHistoryEnabled: Bool = true

    @State private var showClearAllConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("Settings")
                .font(.title2)

            GroupBox("Date Format") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $dateFormatRawValue) {
                        ForEach(QueryResultsDateFormat.allCases) { option in
                            HStack {
                                Text(option.displayName)
                                Spacer(minLength: 12)
                                Text(option.example)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: Constants.FontSize.small, design: .monospaced))
                            }
                            .tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding(.top, 4)
            }

            GroupBox("Query History") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Save query history", isOn: $queryHistoryEnabled)
                    Text("History is kept locally and capped at \(Constants.QueryHistory.maxEntries) entries.")
                        .font(.system(size: Constants.FontSize.small))
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        showClearAllConfirmation = true
                    } label: {
                        Label("Clear all history", systemImage: "trash")
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(width: 520, height: 380, alignment: .topLeading)
        .padding()
        .alert("Clear all query history?", isPresented: $showClearAllConfirmation) {
            Button("Clear", role: .destructive) {
                QueryHistoryService(modelContext: modelContext).clearAll(connectionId: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every history entry across all connections.")
        }
    }
}

#Preview {
    SettingsView()
}
