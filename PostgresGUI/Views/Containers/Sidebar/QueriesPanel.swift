//
//  QueriesPanel.swift
//  PostgresGUI
//
//  Sidebar panel that lets the user switch between saved queries and query history.
//

import SwiftUI

enum QueriesPanelTab: String, CaseIterable, Identifiable {
    case saved
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .saved: return "Saved"
        case .history: return "History"
        }
    }
}

struct QueriesPanel: View {
    let savedQueries: [SavedQuery]
    let folders: [QueryFolder]
    @Binding var selectedQueryIDs: Set<SavedQuery.ID>

    @State private var selectedTab: QueriesPanelTab = .saved

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(QueriesPanelTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.top, 10)

            switch selectedTab {
            case .saved:
                SavedQueriesSidebarSection(
                    savedQueries: savedQueries,
                    folders: folders,
                    selectedQueryIDs: $selectedQueryIDs
                )
            case .history:
                QueryHistorySidebarSection()
            }
        }
    }
}
