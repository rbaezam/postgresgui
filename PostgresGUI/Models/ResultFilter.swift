//
//  ResultFilter.swift
//  PostgresGUI
//
//  Simple equality filter applied to table-browse queries. v1 supports
//  only `column = value` with the value treated as a quoted SQL literal
//  (the same single-quote-doubling pattern used elsewhere). NULL and
//  comparison operators are intentionally deferred.
//

import Foundation

struct ResultFilter: Equatable, Identifiable, Hashable {
    let id: UUID
    let column: String
    let value: String

    init(id: UUID = UUID(), column: String, value: String) {
        self.id = id
        self.column = column
        self.value = value
    }
}
