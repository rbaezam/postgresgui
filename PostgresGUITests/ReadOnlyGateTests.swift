//
//  ReadOnlyGateTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("ReadOnlyGate.isReadSafe")
struct ReadOnlyGateTests {

    // MARK: - Allowed

    @Test func plainSelectIsSafe() {
        #expect(ReadOnlyGate.isReadSafe("SELECT 1"))
        #expect(ReadOnlyGate.isReadSafe("select * from users"))
    }

    @Test func cteWithSelectIsSafe() {
        #expect(ReadOnlyGate.isReadSafe("WITH cte AS (SELECT 1) SELECT * FROM cte"))
    }

    @Test func explainWithoutAnalyzeIsSafe() {
        #expect(ReadOnlyGate.isReadSafe("EXPLAIN SELECT 1"))
        #expect(ReadOnlyGate.isReadSafe("EXPLAIN (FORMAT JSON) SELECT 1"))
        #expect(ReadOnlyGate.isReadSafe("EXPLAIN VERBOSE SELECT * FROM x"))
    }

    @Test func showIsSafe() {
        #expect(ReadOnlyGate.isReadSafe("SHOW server_version"))
    }

    @Test func transactionControlIsSafe() {
        #expect(ReadOnlyGate.isReadSafe("BEGIN"))
        #expect(ReadOnlyGate.isReadSafe("COMMIT"))
        #expect(ReadOnlyGate.isReadSafe("ROLLBACK"))
        #expect(ReadOnlyGate.isReadSafe("SAVEPOINT s1"))
        #expect(ReadOnlyGate.isReadSafe("RELEASE SAVEPOINT s1"))
        #expect(ReadOnlyGate.isReadSafe("START TRANSACTION"))
    }

    @Test func setAndResetAreSafe() {
        #expect(ReadOnlyGate.isReadSafe("SET search_path TO public"))
        #expect(ReadOnlyGate.isReadSafe("SET LOCAL statement_timeout = 1000"))
        #expect(ReadOnlyGate.isReadSafe("RESET search_path"))
    }

    @Test func leadingWhitespaceAndCommentsAreStripped() {
        #expect(ReadOnlyGate.isReadSafe("   SELECT 1"))
        #expect(ReadOnlyGate.isReadSafe("-- just looking\nSELECT 1"))
        #expect(ReadOnlyGate.isReadSafe("/* yo */ SELECT 1"))
        #expect(ReadOnlyGate.isReadSafe("/* a */\n-- b\nSELECT 1"))
    }

    @Test func multipleAllSafeStatements() {
        #expect(ReadOnlyGate.isReadSafe("SELECT 1; SELECT 2;"))
        #expect(ReadOnlyGate.isReadSafe("BEGIN; SELECT 1; COMMIT;"))
    }

    @Test func emptyOrWhitespaceOnlyIsSafe() {
        #expect(ReadOnlyGate.isReadSafe(""))
        #expect(ReadOnlyGate.isReadSafe("   \n\t  "))
        #expect(ReadOnlyGate.isReadSafe("-- only a comment"))
    }

    // MARK: - Blocked

    @Test func dmlIsBlocked() {
        #expect(!ReadOnlyGate.isReadSafe("INSERT INTO users (name) VALUES ('a')"))
        #expect(!ReadOnlyGate.isReadSafe("UPDATE users SET name = 'a'"))
        #expect(!ReadOnlyGate.isReadSafe("DELETE FROM users"))
    }

    @Test func ddlIsBlocked() {
        #expect(!ReadOnlyGate.isReadSafe("DROP TABLE users"))
        #expect(!ReadOnlyGate.isReadSafe("ALTER TABLE users ADD COLUMN x int"))
        #expect(!ReadOnlyGate.isReadSafe("TRUNCATE users"))
        #expect(!ReadOnlyGate.isReadSafe("CREATE TABLE x (id int)"))
        #expect(!ReadOnlyGate.isReadSafe("CREATE INDEX idx ON users(name)"))
        #expect(!ReadOnlyGate.isReadSafe("DROP DATABASE prod"))
    }

    @Test func grantRevokeCommentBlocked() {
        #expect(!ReadOnlyGate.isReadSafe("GRANT SELECT ON users TO bob"))
        #expect(!ReadOnlyGate.isReadSafe("REVOKE SELECT ON users FROM bob"))
        #expect(!ReadOnlyGate.isReadSafe("COMMENT ON TABLE users IS 'x'"))
    }

    @Test func vacuumReindexBlocked() {
        #expect(!ReadOnlyGate.isReadSafe("VACUUM ANALYZE users"))
        #expect(!ReadOnlyGate.isReadSafe("REINDEX TABLE users"))
    }

    @Test func explainAnalyzeMutationIsBlocked() {
        #expect(!ReadOnlyGate.isReadSafe("EXPLAIN ANALYZE INSERT INTO users VALUES (1)"))
        #expect(!ReadOnlyGate.isReadSafe("EXPLAIN (ANALYZE, VERBOSE) UPDATE users SET x=1"))
        #expect(!ReadOnlyGate.isReadSafe("EXPLAIN (ANALYZE) DELETE FROM users"))
    }

    @Test func multiStatementWithOneMutationIsBlocked() {
        #expect(!ReadOnlyGate.isReadSafe("SELECT 1; UPDATE users SET x=1;"))
        #expect(!ReadOnlyGate.isReadSafe("BEGIN; DELETE FROM users; COMMIT;"))
    }

    @Test func unknownVerbFailsClosed() {
        #expect(!ReadOnlyGate.isReadSafe("FROBNICATE everything"))
        #expect(!ReadOnlyGate.isReadSafe("LOAD 'pg_extension'"))
    }
}
