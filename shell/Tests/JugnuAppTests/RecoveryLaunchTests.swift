@testable import Jugnu
import JugnuCore
import XCTest

@MainActor
final class RecoveryLaunchTests: XCTestCase {
    func test_malformedYaml_routesToRecoverySurface() {
        XCTAssertEqual(
            LaunchStart.decide(safeMode: false, configSyntaxError: true),
            .recovery(.malformedConfig)
        )
        XCTAssertEqual(
            LaunchStart.decide(safeMode: true, configSyntaxError: false),
            .recovery(.crashLoop)
        )
        XCTAssertEqual(
            LaunchStart.decide(safeMode: false, configSyntaxError: false),
            .normal
        )
    }

    func test_safeMode_bootsOutAgentsOnEntry() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        try FileManager.default.createDirectory(at: paths.launchAgentsDir, withIntermediateDirectories: true)
        let plist = paths.launchAgentsDir.appendingPathComponent("com.jugnu.keep-awake.watch.plist")
        try "x".write(to: plist, atomically: true, encoding: .utf8)
        let launchctl = RecordingLaunchctl()
        let agents = DaemonAgents(launchctl: launchctl, uid: 501)
        agents.bootoutAllJugnuAgents(paths: paths)
        XCTAssertFalse(FileManager.default.fileExists(atPath: plist.path))
        XCTAssertEqual(launchctl.calls.first, ["bootout", "gui/501/com.jugnu.keep-awake.watch"])
    }

    func test_recoveryMenu_hasFourActions() {
        let bar = MenuBarController(
            onOpenPalette: {},
            onPreferences: {},
            onQuit: {},
            recovery: RecoveryMenuActions(
                onResetConfig: {},
                onOpenConfig: {},
                onDisableAllAddons: {},
                onTryAgain: {}
            )
        )
        XCTAssertEqual(bar.menuItemTitles, [
            RecoveryMenuCopy.resetConfig,
            RecoveryMenuCopy.openConfig,
            RecoveryMenuCopy.disableAddons,
            RecoveryMenuCopy.tryAgain,
            "Quit Jugnu",
        ])
    }
}
