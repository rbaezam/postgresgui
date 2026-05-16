//
//  ConnectionProfileTests.swift
//  PostgresGUITests
//

import Foundation
import SwiftData
import Testing
@testable import PostgresGUI

@Suite("ConnectionProfile")
struct ConnectionProfileTests {

    @Test func defaultsForNewProfile() {
        let profile = ConnectionProfile(
            name: "Test",
            host: "localhost",
            username: "postgres"
        )
        #expect(profile.isReadOnly == false)
        #expect(profile.colorTag == nil)
        #expect(profile.colorTagEnum == nil)
    }

    @Test func colorTagRoundTripsThroughEnum() {
        let profile = ConnectionProfile(
            name: "Prod",
            host: "prod.db",
            username: "postgres",
            colorTag: .red,
            isReadOnly: true
        )
        #expect(profile.colorTag == "red")
        #expect(profile.colorTagEnum == .red)
        #expect(profile.isReadOnly == true)
    }

    @Test func colorTagEnumReturnsNilForUnknownRawValue() {
        let profile = ConnectionProfile(
            name: "Old",
            host: "h",
            username: "u"
        )
        // Simulate forward-compat: a future build wrote an unknown raw value
        profile.colorTag = "magenta"
        #expect(profile.colorTagEnum == nil)
    }

    @MainActor
    @Test func persistsAcrossInMemoryStore() throws {
        let schema = Schema([ConnectionProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let profile = ConnectionProfile(
            name: "Staging",
            host: "staging.db",
            username: "postgres",
            colorTag: .blue,
            isReadOnly: true
        )
        context.insert(profile)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ConnectionProfile>())
        let stored = try #require(fetched.first)
        #expect(stored.colorTag == "blue")
        #expect(stored.colorTagEnum == .blue)
        #expect(stored.isReadOnly == true)
    }
}
