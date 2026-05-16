//
//  PaletteCommand.swift
//  PostgresGUI
//

import Foundation

struct PaletteCommand: Identifiable {
    enum Kind: Int, Comparable {
        case table = 0
        case savedQuery = 1
        case action = 2

        static func < (lhs: Kind, rhs: Kind) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var sectionTitle: String {
            switch self {
            case .table: return "Tables"
            case .savedQuery: return "Saved Queries"
            case .action: return "Actions"
            }
        }
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let systemImage: String
    let perform: () -> Void
}
