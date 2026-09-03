import Foundation

public enum CleanupError: Error, Equatable {
    case disableIncomplete(labels: [String])
}

public enum Cleanup {
    public static func performDisable(manifest: AddonManifest, addonRoot: URL, paths: JugnuPaths) throws {
        _ = addonRoot
        var survivors: [String] = []
        for label in manifest.effectiveCleanupLaunchd() {
            // Remove the plist before bootout so launchd can't reload the job at next login.
            let plist = paths.launchAgentsDir.appendingPathComponent("\(label).plist")
            try? FileManager.default.removeItem(at: plist)
            bestEffortLaunchctlBootout(label: label)
            if launchctlLabelIsLoaded(label) {
                survivors.append(label)
            }
        }
        if !survivors.isEmpty {
            throw CleanupError.disableIncomplete(labels: survivors)
        }
    }

    /// Disable cleanup, delete declared paths, then remove the addon directory.
    public static func performUninstall(manifest: AddonManifest, addonRoot: URL, paths: JugnuPaths) throws {
        try performDisable(manifest: manifest, addonRoot: addonRoot, paths: paths)
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

    public static func removeOrphanedHelpers(
        declared: [HelperRef],
        excludingAddon: String,
        paths: JugnuPaths
    ) throws {
        let fm = FileManager.default
        for ref in declared {
            if anotherAddonLists(ref, excludingAddon: excludingAddon, paths: paths) {
                continue
            }
            let root = paths.helperRoot(id: ref.id, version: ref.version)
            if fm.fileExists(atPath: root.path) {
                try fm.removeItem(at: root)
            }
            let idDir = paths.helpersDir.appendingPathComponent(ref.id)
            if fm.fileExists(atPath: idDir.path),
               (try? fm.contentsOfDirectory(atPath: idDir.path))?.isEmpty == true
            {
                try fm.removeItem(at: idDir)
            }
        }
    }

    private static func anotherAddonLists(
        _ ref: HelperRef,
        excludingAddon: String,
        paths: JugnuPaths
    ) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.addonsDir.path),
              let children = try? fm.contentsOfDirectory(
                  at: paths.addonsDir,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              )
        else { return false }
        for child in children where child.lastPathComponent != excludingAddon {
            guard let manifest = try? ManifestLoader.load(from: child) else { continue }
            if manifest.helpers.contains(ref) {
                return true
            }
        }
        return false
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

    private static func launchctlLabelIsLoaded(_ label: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())/\(label)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private static func bestEffortLaunchctlBootout(label: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            return
        }

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
            try Cleanup.performDisable(manifest: manifest, addonRoot: addonRoot, paths: paths)
        }
        config.addons[id] = AddonConfig(enabled: enabled)
        try store.save(config)
    }

    public func uninstall(id: String) throws {
        let addonRoot = paths.addonsDir.appendingPathComponent(id)
        if FileManager.default.fileExists(atPath: addonRoot.appendingPathComponent("addon.yaml").path) {
            let manifest = try ManifestLoader.load(from: addonRoot)
            try Cleanup.performUninstall(manifest: manifest, addonRoot: addonRoot, paths: paths)
            try Cleanup.removeOrphanedHelpers(
                declared: manifest.helpers,
                excludingAddon: id,
                paths: paths
            )
        } else if FileManager.default.fileExists(atPath: addonRoot.path) {
            try FileManager.default.removeItem(at: addonRoot)
        }
        var config = try store.loadOrCreateDefaults()
        config.addons.removeValue(forKey: id)
        try store.save(config)
    }
}
