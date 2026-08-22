import XCTest
@testable import JugnuCore

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
        XCTAssertTrue(index.search("nope").isEmpty)
        XCTAssertEqual(index.search("").count, 1)
    }

    func testExtraAddonRoots() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let fixtureRoot = try XCTUnwrap(
            Bundle.module.url(forResource: "addon", withExtension: "yaml", subdirectory: "Fixtures/mic-mute")?
                .deletingLastPathComponent()
        )
        var config = JugnuConfig()
        config.addons["mic-mute"] = AddonConfig(enabled: true)

        var index = CommandIndex(
            paths: JugnuPaths(home: home),
            config: config,
            extraAddonRoots: [fixtureRoot]
        )
        try index.rebuild()
        XCTAssertEqual(index.all.first?.addonId, "mic-mute")
    }
}
