import Foundation
import JugnuCore

/// Deterministic setup for the screenshot UI-test flow. Active only when
/// `JUGNU_SCREENSHOT_MODE=1` is in the environment. Everything it does is
/// gated behind that check, so a normal launch is completely unaffected.
///
/// It builds a throwaway `$HOME` under a temp directory, copies the repo's
/// local `addons/` into place, marks first-run complete, and seeds a fixed
/// favorites list — so every screenshot run starts from the same state and
/// never touches the developer's real `~/.config/jugnu`.
enum ScreenshotMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.environment["JUGNU_SCREENSHOT_MODE"] == "1"
    }

    /// Favorites seeded into row1 (qualified command ids: `<addon>.<command>`).
    static let seededFavorites = [
        "mic-mute.toggle",
        "focus-toggle.toggle",
        "paste-plain.paste-plain",
        "clipboard-history.open",
        "ports.list",
    ]

    /// Local addon ids to enable in the sandbox config.
    static let enabledAddons = [
        "mic-mute", "focus-toggle", "paste-plain", "clipboard-history", "ports",
        "floating-note", "nudges", "world-clock", "battery-eta", "window-layouts",
        "ui-demo-confirm", "ui-demo-form", "ui-demo-list",
    ]

    /// Prepares the sandbox and returns the `JugnuPaths` the app should use.
    /// Returns `nil` (and the caller falls back to the normal paths) if anything fails.
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
