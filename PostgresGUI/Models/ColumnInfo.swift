//
//  ColumnInfo.swift
//  PostgresGUI
//
//  Created by ghazi on 11/28/25.
//

import Foundation

struct ColumnInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let dataType: String
    var isNullable: Bool
    var defaultValue: String?
    var isPrimaryKey: Bool
    var isUnique: Bool
    var isForeignKey: Bool

    // Single-column foreign key target. Populated by the metadata fetch
    // when this column is a non-composite FK; otherwise nil.
    var referencedSchema: String?
    var referencedTable: String?
    var referencedColumn: String?

    struct ForeignKeyTarget: Equatable, Hashable {
        let schema: String
        let table: String
        let column: String
    }

    var foreignKeyTarget: ForeignKeyTarget? {
        guard let s = referencedSchema,
              let t = referencedTable,
              let c = referencedColumn else {
            return nil
        }
        return ForeignKeyTarget(schema: s, table: t, column: c)
    }

    init(
        name: String,
        dataType: String,
        isNullable: Bool = true,
        defaultValue: String? = nil,
        isPrimaryKey: Bool = false,
        isUnique: Bool = false,
        isForeignKey: Bool = false,
        referencedSchema: String? = nil,
        referencedTable: String? = nil,
        referencedColumn: String? = nil
    ) {
        self.id = name
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.defaultValue = defaultValue
        self.isPrimaryKey = isPrimaryKey
        self.isUnique = isUnique
        self.isForeignKey = isForeignKey
        self.referencedSchema = referencedSchema
        self.referencedTable = referencedTable
        self.referencedColumn = referencedColumn
    }
}
