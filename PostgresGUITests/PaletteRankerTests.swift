//
//  PaletteRankerTests.swift
//  PostgresGUITests
//

import Foundation
import Testing
@testable import PostgresGUI

@Suite("PaletteRanker")
struct PaletteRankerTests {

    private func make(
        title: String,
        subtitle: String? = nil,
        kind: PaletteCommand.Kind = .action
    ) -> PaletteCommand {
        PaletteCommand(
            id: title,
            kind: kind,
            title: title,
            subtitle: subtitle,
            systemImage: "circle",
            perform: {}
        )
    }

    // MARK: - filter

    @Test func emptyQueryReturnsAllInOrder() {
        let cmds = [make(title: "users"), make(title: "orders")]
        let out = PaletteRanker.filter(cmds, query: "")
        #expect(out.map(\.title) == ["users", "orders"])
    }

    @Test func whitespaceOnlyQueryReturnsAllInOrder() {
        let cmds = [make(title: "users"), make(title: "orders")]
        let out = PaletteRanker.filter(cmds, query: "   \n\t")
        #expect(out.map(\.title) == ["users", "orders"])
    }

    @Test func noMatchesDroppedFromResults() {
        let cmds = [make(title: "users"), make(title: "orders")]
        #expect(PaletteRanker.filter(cmds, query: "zzz").isEmpty)
    }

    @Test func higherScoresSortFirst() {
        let cmds = [
            make(title: "user_settings"),     // word-prefix on "user"
            make(title: "users"),              // title-prefix on "user"
            make(title: "current_user"),       // substring on "user"
        ]
        let out = PaletteRanker.filter(cmds, query: "user")
        #expect(out.map(\.title) == ["users", "user_settings", "current_user"])
    }

    @Test func tiesBreakByKindThenTitle() {
        let cmds = [
            make(title: "users", kind: .action),
            make(title: "users", kind: .table),
            make(title: "users", kind: .savedQuery),
        ]
        let out = PaletteRanker.filter(cmds, query: "users")
        #expect(out.map(\.kind) == [.table, .savedQuery, .action])
    }

    // MARK: - score

    @Test func exactMatch() {
        #expect(PaletteRanker.score(make(title: "users"), query: "users") == 100)
    }

    @Test func caseInsensitive() {
        #expect(PaletteRanker.score(make(title: "Users"), query: "users") == 100)
        #expect(PaletteRanker.score(make(title: "USERS"), query: "Users") == 100)
    }

    @Test func titlePrefix() {
        #expect(PaletteRanker.score(make(title: "users_archive"), query: "users") == 90)
    }

    @Test func wordPrefix() {
        // "public.users" → tokens "public", "users". "us" hits "users".
        #expect(PaletteRanker.score(make(title: "public.users"), query: "us") == 80)
        #expect(PaletteRanker.score(make(title: "current_user_id"), query: "user") == 80)
    }

    @Test func substring() {
        #expect(PaletteRanker.score(make(title: "customer_users"), query: "stom") == 50)
    }

    @Test func noMatch() {
        #expect(PaletteRanker.score(make(title: "orders"), query: "users") == 0)
    }

    @Test func subtitleHitCapsAt60() {
        let cmd = make(title: "row", subtitle: "users")
        // "users" → exact subtitle match would normally score 100, but
        // subtitle hits are capped at 60 so titles always beat subtitles.
        #expect(PaletteRanker.score(cmd, query: "users") == 60)
    }

    @Test func titleStillBeatsSubtitleAtSameTier() {
        let onlySubtitle = make(title: "row", subtitle: "users")     // 60 from subtitle
        let titlePrefix = make(title: "users_archive", subtitle: nil) // 90 from title
        let out = PaletteRanker.filter([onlySubtitle, titlePrefix], query: "users")
        #expect(out.map(\.title) == ["users_archive", "row"])
    }
}
