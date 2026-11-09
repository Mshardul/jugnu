@testable import JugnuCore
import XCTest

final class CommandIndexTests: XCTestCase {
    func testEnabledAppearsDisabledOmittedAndSearchFilters() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let fixtureRoot = try XCTUnwrap(
            Bundle.module.url(forResource: "addon", withExtension: "yaml", subdirectory: "Fixtures/mic-mute")?
                .deletingLastPathComponent()
        )
        let installed = paths.addonsDir.appendingPathComponent("mic-mute")
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: fixtureRoot.appendingPathComponent("addon.yaml"),
            to: installed.appendingPathComponent("addon.yaml")
        )

        var config = JugnuConfig()
        config.addons["mic-mute"] = AddonConfig(enabled: true)

        var index = CommandIndex(paths: paths, config: config)
        try index.rebuild()
        XCTAssertEqual(index.all.count, 1)
        XCTAssertEqual(index.all.first?.commandId, "toggle")

        config.addons["mic-mute"] = AddonConfig(enabled: false)
        index.config = config
        try index.rebuild()
        XCTAssertTrue(index.all.isEmpty)

        config.addons["mic-mute"] = AddonConfig(enabled: true)
        index.config = config
        try index.rebuild()
        XCTAssertEqual(index.search("mic").count, 1)
        XCTAssertEqual(index.search("").count, 1)
        let suggestions = index.searchHits("nope")
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertTrue(suggestions[0].isSuggestion)
    }

    func testTitleTierBeatsKeywordEvenIfKeywordScoreHigher() {
        let zoom = IndexedCommand(
            addonId: "a",
            commandId: "z",
            title: "Zoom",
            subtitle: "",
            keywords: ["mic mute"],
            addonRoot: URL(fileURLWithPath: "/tmp")
        )
        let mute = IndexedCommand(
            addonId: "b",
            commandId: "t",
            title: "Mic Mute",
            subtitle: "",
            keywords: [],
            addonRoot: URL(fileURLWithPath: "/tmp")
        )
        var index = CommandIndex(paths: JugnuPaths(home: URL(fileURLWithPath: "/tmp")), config: JugnuConfig())
        index.replaceCommandsForTesting([zoom, mute])
        XCTAssertEqual(index.search("mcmt").first?.title, "Mic Mute")
    }

    private func command(_ addon: String, _ id: String, _ title: String, alias: String? = nil) -> IndexedCommand {
        IndexedCommand(
            addonId: addon, commandId: id, title: title, subtitle: "", keywords: [],
            alias: alias, addonRoot: URL(fileURLWithPath: "/tmp")
        )
    }

    func testExactAliasRanksFirstEvenWhenFuzzyPrefersAnother() {
        var index = CommandIndex(paths: JugnuPaths(home: URL(fileURLWithPath: "/tmp")), config: JugnuConfig())
        index.replaceCommandsForTesting([
            command("jugnu.a", "mute-mic", "Mute microphone input"),
            command("jugnu.b", "mute-all", "Quiet everything", alias: "Mute")
        ])
        XCTAssertEqual(index.searchHits("mute").first?.command.commandId, "mute-all")
        XCTAssertEqual(index.searchHits("  MUTE ").first?.command.commandId, "mute-all")
        XCTAssertEqual(index.searchHits("mute").count, 2)
    }

    func testNonMatchingQueryFallsBackToFuzzyOrder() {
        var index = CommandIndex(paths: JugnuPaths(home: URL(fileURLWithPath: "/tmp")), config: JugnuConfig())
        index.replaceCommandsForTesting([
            command("jugnu.a", "mute-mic", "Mute microphone", alias: "mm"),
            command("jugnu.b", "mute-all", "Mute all", alias: "mute-all")
        ])
        XCTAssertEqual(index.searchHits("mut").first?.command.commandId, "mute-all")
    }

    func testDuplicateAliasKeepsSingleFirstPartyAndDropsAmbiguousTies() {
        var index = CommandIndex(paths: JugnuPaths(home: URL(fileURLWithPath: "/tmp")), config: JugnuConfig())
        index.replaceCommandsForTesting([
            command("acme.x", "one", "One", alias: "go"),
            command("jugnu.y", "two", "Two", alias: "go"),
            command("acme.p", "three", "Three", alias: "tie"),
            command("beta.q", "four", "Four", alias: "tie")
        ])
        let byId = Dictionary(uniqueKeysWithValues: index.all.map { ($0.commandId, $0.alias) })
        XCTAssertNil(byId["one"] ?? nil)
        XCTAssertEqual(byId["two"] ?? nil, "go")
        XCTAssertNil(byId["three"] ?? nil)
        XCTAssertNil(byId["four"] ?? nil)
    }
}
