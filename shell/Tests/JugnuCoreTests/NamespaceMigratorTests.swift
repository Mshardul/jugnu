import XCTest
@testable import JugnuCore

final class NamespaceMigratorTests: XCTestCase {
    private var home: URL!
    private var paths: JugnuPaths!
    private var store: ConfigStore!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("ns-mig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        paths = JugnuPaths(home: home)
        store = ConfigStore(paths: paths)
        try FileManager.default.createDirectory(at: paths.addonsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.stateDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    func testMigrateOneAndResume() throws {
        try writeBareAddon(job: "mic-mute")
        try writeBareAddon(job: "ports")
        var config = try store.loadOrCreateDefaults()
        config.addons["mic-mute"] = AddonConfig(enabled: true)
        config.addons["ports"] = AddonConfig(enabled: false)
        try store.save(config)

        let stateStore = StateStore(paths: paths)
        var state = JugnuState()
        state.recentCommandIDs = ["mic-mute.toggle", "ports.list"]
        state.favoriteCommandIDs = ["mic-mute.toggle"]
        try stateStore.save(state)

        // Migrate only first id to simulate mid-pass crash.
        try NamespaceMigrator.migrateOne(job: "mic-mute", paths: paths, store: store, stateStore: stateStore)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.addonsDir.appendingPathComponent("mic-mute").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.addonsDir.appendingPathComponent("jugnu.mic-mute").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.addonsDir.appendingPathComponent("ports").path))

        let mid = try NamespaceMigrator.migrateInstalledTree(paths: paths, store: store, stateStore: stateStore)
        XCTAssertEqual(mid, ["ports"])

        let cfg = try store.loadOrCreateDefaults()
        XCTAssertEqual(cfg.addons["jugnu.mic-mute"]?.enabled, true)
        XCTAssertEqual(cfg.addons["jugnu.ports"]?.enabled, false)
        XCTAssertNil(cfg.addons["mic-mute"])

        let st = try stateStore.load()
        XCTAssertEqual(st.recentCommandIDs, ["jugnu.mic-mute.toggle", "jugnu.ports.list"])
        XCTAssertEqual(st.favoriteCommandIDs, ["jugnu.mic-mute.toggle"])

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: NamespaceMigrator.completionMarker(paths: paths).path)
        )

        // Second pass is no-op.
        let again = try NamespaceMigrator.migrateInstalledTree(paths: paths, store: store, stateStore: stateStore)
        XCTAssertEqual(again, [])
    }

    func testCollisionRefuse() throws {
        try writeBareAddon(job: "clip-tools")
        let other = paths.addonsDir.appendingPathComponent("other.clip-tools")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        XCTAssertThrowsError(
            try NamespaceMigrator.migrateOne(job: "clip-tools", paths: paths, store: store)
        ) {
            guard case NamespaceMigratorError.collision = $0 else {
                return XCTFail("\(String(describing: $0))")
            }
        }
    }

    private func writeBareAddon(job: String) throws {
        let dir = paths.addonsDir.appendingPathComponent(job)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        id: \(job)
        name: \(job)
        version: 1.0.0
        api: 1
        commands:
          - id: toggle
            title: T
            subtitle: s
            keywords: []
        entrypoint:
          kind: exec
          path: bin/run
        """.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
    }
}
