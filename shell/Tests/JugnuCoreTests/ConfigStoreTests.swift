@testable import JugnuCore
import XCTest

final class ConfigStoreTests: XCTestCase {
    func testLoadMissingCreatesDefaults() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(paths: JugnuPaths(home: dir))
        let config = try store.loadOrCreateDefaults()
        XCTAssertEqual(config.shell.hotkey, "option+space")
        XCTAssertEqual(config.shell.registryURL, ShellConfig.defaultRegistryURL)
        XCTAssertEqual(config.theme.dark.accent, "#F5A623")
        XCTAssertEqual(config.sound, true)
        XCTAssertEqual(config.shell.hiddenShellCommands, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.paths.configFile.path))
    }

    func testRoundTripHiddenShellCommands() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(paths: JugnuPaths(home: dir))
        var config = try store.loadOrCreateDefaults()
        config.shell.hiddenShellCommands = ["browse-addons"]
        try store.save(config)
        let loaded = try store.load()
        XCTAssertEqual(loaded.shell.hiddenShellCommands, ["browse-addons"])
    }

    func testRoundTripRegistryURL() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(paths: JugnuPaths(home: dir))
        var config = try store.loadOrCreateDefaults()
        config.shell.registryURL = "https://example.com/addons.json"
        try store.save(config)
        let loaded = try store.load()
        XCTAssertEqual(loaded.shell.registryURL, "https://example.com/addons.json")
    }

    func testRoundTripEnableFlag() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(paths: JugnuPaths(home: dir))
        var config = try store.loadOrCreateDefaults()
        config.addons["mic-mute"] = AddonConfig(enabled: true)
        try store.save(config)
        let loaded = try store.load()
        XCTAssertEqual(loaded.addons["mic-mute"]?.enabled, true)
    }

    func testLoadSampleFixture() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let paths = JugnuPaths(home: dir)
        try FileManager.default.createDirectory(
            at: paths.configFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let fixture = try XCTUnwrap(
            Bundle.module.url(forResource: "sample-config", withExtension: "yaml", subdirectory: "Fixtures")
        )
        try FileManager.default.copyItem(at: fixture, to: paths.configFile)

        let loaded = try ConfigStore(paths: paths).load()
        XCTAssertEqual(loaded.version, 1)
        XCTAssertEqual(loaded.shell.hotkey, "option+space")
        XCTAssertEqual(loaded.addons["mic-mute"]?.enabled, true)
        XCTAssertEqual(loaded.addons["paste-plain"]?.enabled, false)
    }
}
