//
//  DatabaseError.swift
//  PostgresGUI
//
//  Created by ghazi on 11/29/25.
//

import Foundation

enum DatabaseError: Error, LocalizedError {
    case noPrimaryKey
    case missingPrimaryKeyValue(column: String)
    case queryFailed(String)
    case unknownError(String)
    case timeout
    case readOnlyViolation

    var errorDescription: String? {
        switch self {
        case .noPrimaryKey:
            return "This table has no primary key. DELETE and EDIT operations require a primary key."
        case .missingPrimaryKeyValue(let column):
            return "Missing primary key value for column: \(column)"
        case .queryFailed(let message):
            return message
        case .unknownError(let message):
            return message
        case .timeout:
            return "The operation timed out. The database may be slow or unresponsive."
        case .readOnlyViolation:
            return "This connection is read-only. INSERT, UPDATE, DELETE, and other data-changing statements are blocked. Disable read-only mode in the connection settings to make changes."
        }
    }

    /// Check if an error is a timeout error
    static func isTimeout(_ error: Error) -> Bool {
        if let dbError = error as? DatabaseError, case .timeout = dbError {
            return true
        }
        return false
    }
}
