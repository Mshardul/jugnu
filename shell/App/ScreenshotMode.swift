import Foundation
import JugnuCore

// builds a throwaway $HOME so screenshot runs never touch the real ~/.config/jugnu
enum ScreenshotMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.environment["JUGNU_SCREENSHOT_MODE"] == "1"
    }

    static let seededFavorites = [
        "jugnu.audio-toggles.mute-mic",
        "jugnu.focus-toggle.toggle",
        "jugnu.paste-plain.paste-plain",
        "jugnu.clipboard-history.open",
        "jugnu.ports.list",
    ]

    static let enabledAddons = [
        "jugnu.audio-toggles", "jugnu.focus-toggle", "jugnu.paste-plain", "jugnu.clipboard-history", "jugnu.ports",
        "jugnu.floating-note", "jugnu.nudges", "jugnu.world-clock", "jugnu.battery-eta", "jugnu.window-layouts",
        "jugnu.ui-demo-confirm", "jugnu.ui-demo-form", "jugnu.ui-demo-list",
    ]

    // nil on any failure; caller falls back to the normal paths
    static func makePaths() -> JugnuPaths? {
        let fm = FileManager.default
        let env = ProcessInfo.processInfo.environment

        // A stable location so repeated runs reuse (and refresh) the same sandbox.
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("jugnu-screenshots-home", isDirectory: true)

        let paths = JugnuPaths(home: home)

        do {
            // Fresh each run.
            if fm.fileExists(atPath: home.path) {
                try fm.removeItem(at: home)
            }
            try fm.createDirectory(at: paths.addonsDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: paths.stateDir, withIntermediateDirectories: true)
            try fm.createDirectory(
                at: paths.configFile.deletingLastPathComponent(), withIntermediateDirectories: true
            )

            // Copy local addons from the repo (path passed by the test runner).
            if let repoAddons = env["JUGNU_REPO_ADDONS"], !repoAddons.isEmpty {
                let src = URL(fileURLWithPath: repoAddons)
                for id in enabledAddons {
                    let from = src.appendingPathComponent(id)
                    let to = paths.addonsDir.appendingPathComponent(id)
                    if fm.fileExists(atPath: from.path) {
                        try? fm.copyItem(at: from, to: to)
                    }
                }
            }

            // Seed config: enable the copied addons.
            var config = JugnuConfig()
            for id in enabledAddons {
                config.addons[id] = AddonConfig(enabled: true)
            }
            try ConfigStore(paths: paths).save(config)

            // Seed state: first-run done, fixed favorites.
            let state = JugnuState(
                firstRunCompleted: true,
                recentCommandIDs: [],
                favoriteCommandIDs: seededFavorites
            )
            try StateStore(paths: paths).save(state)

            return paths
        } catch {
            NSLog("ScreenshotMode: sandbox setup failed: \(error)")
            return nil
        }
    }
}
