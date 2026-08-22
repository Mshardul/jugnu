import Foundation

public enum Cleanup {
    /// Best-effort undo of declared running side effects. Does not delete the addon directory.
    public static func performDisable(manifest: AddonManifest, addonRoot: URL) throws {
        _ = addonRoot
        for label in manifest.cleanup.launchd {
            bestEffortLaunchctlBootout(label: label)
        }
    }

    /// Disable cleanup, delete declared paths, then remove the addon directory.
    public static func performUninstall(manifest: AddonManifest, addonRoot: URL, paths: JugnuPaths) throws {
        _ = paths
        try performDisable(manifest: manifest, addonRoot: addonRoot)
        let fm = FileManager.default
        for raw in manifest.cleanup.paths {
            let url = expandHome(raw)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
        if fm.fileExists(atPath: addonRoot.path) {
            try fm.removeItem(at: addonRoot)
        }
    }

    private static func expandHome(_ path: String) -> URL {
        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(String(path.dropFirst(2)))
        }
        if path == "~" {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: path)
    }

    private static func bestEffortLaunchctlBootout(label: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 { return }

        let fallback = Process()
        fallback.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        fallback.arguments = ["unload", label]
        fallback.standardOutput = Pipe()
        fallback.standardError = Pipe()
        try? fallback.run()
        fallback.waitUntilExit()
    }
}

public struct AddonLifecycle: Sendable {
    public let paths: JugnuPaths
    public let store: ConfigStore

    public init(paths: JugnuPaths, store: ConfigStore? = nil) {
        self.paths = paths
        self.store = store ?? ConfigStore(paths: paths)
    }

    public func setEnabled(id: String, enabled: Bool) throws {
        var config = try store.loadOrCreateDefaults()
        let addonRoot = paths.addonsDir.appendingPathComponent(id)
        if !enabled, FileManager.default.fileExists(atPath: addonRoot.appendingPathComponent("addon.yaml").path) {
            let manifest = try ManifestLoader.load(from: addonRoot)
            try Cleanup.performDisable(manifest: manifest, addonRoot: addonRoot)
        }
        config.addons[id] = AddonConfig(enabled: enabled)
        try store.save(config)
    }

    public func uninstall(id: String) throws {
        let addonRoot = paths.addonsDir.appendingPathComponent(id)
        if FileManager.default.fileExists(atPath: addonRoot.appendingPathComponent("addon.yaml").path) {
            let manifest = try ManifestLoader.load(from: addonRoot)
            try Cleanup.performUninstall(manifest: manifest, addonRoot: addonRoot, paths: paths)
        } else if FileManager.default.fileExists(atPath: addonRoot.path) {
            try FileManager.default.removeItem(at: addonRoot)
        }
        var config = try store.loadOrCreateDefaults()
        config.addons.removeValue(forKey: id)
        try store.save(config)
    }
}
