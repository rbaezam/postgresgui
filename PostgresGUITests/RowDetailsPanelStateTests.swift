//
//  RowDetailsPanelStateTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("RowDetailsPanel.resolveState")
struct RowDetailsPanelStateTests {

    private func makeRow(_ marker: String) -> TableRow {
        TableRow(values: ["marker": marker])
    }

    @Test func emptySelectionReturnsEmpty() {
        let rows = [makeRow("a"), makeRow("b")]
        let state = RowDetailsPanel.resolveState(selectedRowIDs: [], rows: rows)
        #expect(state == .empty)
    }

    @Test func singleSelectionWithMatchingRowReturnsSingle() {
        let row = makeRow("a")
        let rows = [row, makeRow("b")]
        let state = RowDetailsPanel.resolveState(
            selectedRowIDs: [row.id],
            rows: rows
        )
        #expect(state == .single(row))
    }

    @Test func singleSelectionWithMissingRowReturnsEmpty() {
        let rows = [makeRow("a"), makeRow("b")]
        let staleID = UUID()
        let state = RowDetailsPanel.resolveState(
            selectedRowIDs: [staleID],
            rows: rows
        )
        #expect(state == .empty)
    }

    @Test func multipleSelectionReturnsMultiple() {
        let a = makeRow("a")
        let b = makeRow("b")
        let c = makeRow("c")
        let state = RowDetailsPanel.resolveState(
            selectedRowIDs: [a.id, b.id, c.id],
            rows: [a, b, c]
        )
        #expect(state == .multiple(count: 3))
    }
}

