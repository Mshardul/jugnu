@testable import JugnuCore
import XCTest

final class CleanupTests: XCTestCase {
    func testDisableKeepsAddonDirUninstallRemovesDirAndCleanupPaths() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let addonRoot = paths.addonsDir.appendingPathComponent("toy")
        try FileManager.default.createDirectory(at: addonRoot, withIntermediateDirectories: true)

        let sideDir = home.appendingPathComponent(".config/jugnu/addons/toy")
        try FileManager.default.createDirectory(at: sideDir, withIntermediateDirectories: true)
        let side = sideDir.appendingPathComponent("side-effect.txt")
        try "x".write(to: side, atomically: true, encoding: .utf8)

        let yaml = """
        id: toy
        name: Toy
        version: 1.0.0
        api: 1
        commands: []
        entrypoint:
          kind: exec
          path: bin/run
        cleanup:
          paths:
            - "~/.config/jugnu/addons/toy"
          launchd: []
        """
        try yaml.write(to: addonRoot.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)

        let stateRoot = paths.addonStateRoot(id: "toy")
        try FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)
        try "state".write(to: stateRoot.appendingPathComponent("data.txt"), atomically: true, encoding: .utf8)

        let manifest = try ManifestLoader.load(from: addonRoot)
        try Cleanup.performDisable(manifest: manifest, addonRoot: addonRoot, paths: paths)
        XCTAssertTrue(FileManager.default.fileExists(atPath: addonRoot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: side.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateRoot.path))

        let life = AddonLifecycle(paths: paths)
        try life.setEnabled(id: "toy", enabled: true)
        try life.uninstall(id: "toy")

        XCTAssertFalse(FileManager.default.fileExists(atPath: addonRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: side.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateRoot.path), "uninstall must remove addon state root")
        let config = try ConfigStore(paths: paths).load()
        XCTAssertNil(config.addons["toy"])
    }

    func testDisableRemovesLaunchAgentPlistSoWatcherCannotReloadAtLogin() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let addonRoot = paths.addonsDir.appendingPathComponent("watchy")
        try FileManager.default.createDirectory(at: addonRoot, withIntermediateDirectories: true)

        try FileManager.default.createDirectory(at: paths.launchAgentsDir, withIntermediateDirectories: true)
        let plist = paths.launchAgentsDir.appendingPathComponent("com.jugnu.watchy.watch.plist")
        try "<plist/>".write(to: plist, atomically: true, encoding: .utf8)

        let yaml = """
        id: jugnu.watchy
        name: Watchy
        version: 1.0.0
        api: 1
        commands: []
        entrypoint:
          kind: exec
          path: bin/run
        cleanup:
          paths: []
          launchd:
            - com.jugnu.watchy.watch
        """
        try yaml.write(to: addonRoot.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)

        let manifest = try ManifestLoader.load(from: addonRoot)
        try Cleanup.performDisable(manifest: manifest, addonRoot: addonRoot, paths: paths)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: plist.path),
            "disable must delete the LaunchAgent plist so launchd cannot reload the watcher at next login"
        )
    }

    func testUninstallRemovesAddonWhoseManifestNowFailsValidationWithoutRunningItsCleanup() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let addonRoot = paths.addonsDir.appendingPathComponent("jugnu.evil")
        try FileManager.default.createDirectory(at: addonRoot, withIntermediateDirectories: true)
        let victim = home.appendingPathComponent("Documents/keep.txt")
        try FileManager.default.createDirectory(
            at: victim.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "precious".write(to: victim, atomically: true, encoding: .utf8)
        let stateRoot = paths.addonStateRoot(id: "jugnu.evil")
        try FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)

        try """
        id: jugnu.evil
        name: Evil
        version: 1.0.0
        api: 1
        commands: []
        entrypoint:
          kind: exec
          path: bin/run
        cleanup:
          paths:
            - "~/Documents"
          launchd: []
        """.write(to: addonRoot.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)

        let life = AddonLifecycle(paths: paths)
        try life.setEnabled(id: "jugnu.evil", enabled: false)
        try life.uninstall(id: "jugnu.evil")

        XCTAssertFalse(FileManager.default.fileExists(atPath: addonRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateRoot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: victim.path), "invalid manifest cleanup must never run")
    }
}
