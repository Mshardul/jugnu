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

        let side = home.appendingPathComponent("side-effect.txt")
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
            - \(side.path)
          launchd: []
        """
        try yaml.write(to: addonRoot.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)

        let manifest = try ManifestLoader.load(from: addonRoot)
        try Cleanup.performDisable(manifest: manifest, addonRoot: addonRoot, paths: paths)
        XCTAssertTrue(FileManager.default.fileExists(atPath: addonRoot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: side.path))

        let life = AddonLifecycle(paths: paths)
        try life.setEnabled(id: "toy", enabled: true)
        try life.uninstall(id: "toy")

        XCTAssertFalse(FileManager.default.fileExists(atPath: addonRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: side.path))
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
        id: watchy
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
}
