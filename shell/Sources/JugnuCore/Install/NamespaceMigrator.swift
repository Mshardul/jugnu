import Foundation

public enum NamespaceMigratorError: Error, Equatable {
    case collision(job: String, occupant: String)
}

/// Resumable per-addon migration of un-prefixed first-party dirs → `jugnu.<job>`.
public enum NamespaceMigrator {
    public static let firstPartyPublisher = "jugnu"
    public static let completionMarkerName = "namespace-migration-v1-complete"

    public static func namespacedId(forJob job: String) -> String {
        "\(firstPartyPublisher).\(job)"
    }

    public static func isNamespaced(_ id: String) -> Bool {
        id.contains(".")
    }

    public static func completionMarker(paths: JugnuPaths) -> URL {
        paths.stateDir.appendingPathComponent(completionMarkerName)
    }

    /// Migrate remaining un-prefixed addon dirs one id at a time. Safe to call every launch.
    @discardableResult
    public static func migrateInstalledTree(
        paths: JugnuPaths,
        store: ConfigStore,
        stateStore: StateStore? = nil
    ) throws -> [String] {
        let marker = completionMarker(paths: paths)
        let fm = FileManager.default
        try fm.createDirectory(at: paths.addonsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: paths.stateDir, withIntermediateDirectories: true)

        let kids = (try? fm.contentsOfDirectory(
            at: paths.addonsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var unprefixed: [String] = []
        for dir in kids {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let name = dir.lastPathComponent
            if name.hasPrefix(".") { continue }
            if !isNamespaced(name) {
                unprefixed.append(name)
            }
        }
        unprefixed.sort()

        if unprefixed.isEmpty {
            if !fm.fileExists(atPath: marker.path) {
                try Data().write(to: marker)
            }
            return []
        }

        try? fm.removeItem(at: marker)

        var migrated: [String] = []
        for job in unprefixed {
            try migrateOne(job: job, paths: paths, store: store, stateStore: stateStore)
            migrated.append(job)
        }

        let remaining = ((try? fm.contentsOfDirectory(at: paths.addonsDir, includingPropertiesForKeys: nil)) ?? [])
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix(".") && !isNamespaced($0) }
        if remaining.isEmpty {
            try Data().write(to: marker)
        }
        return migrated
    }

    public static func migrateOne(
        job: String,
        paths: JugnuPaths,
        store: ConfigStore,
        stateStore: StateStore? = nil
    ) throws {
        let fm = FileManager.default
        let source = paths.addonsDir.appendingPathComponent(job)
        let destId = namespacedId(forJob: job)
        let dest = paths.addonsDir.appendingPathComponent(destId)

        guard fm.fileExists(atPath: source.path) else { return }

        if fm.fileExists(atPath: dest.path) {
            throw NamespaceMigratorError.collision(job: job, occupant: destId)
        }

        let others = ((try? fm.contentsOfDirectory(at: paths.addonsDir, includingPropertiesForKeys: nil)) ?? [])
            .map(\.lastPathComponent)
            .filter { $0 != job && DependencyResolver.jobKey(for: $0) == job }
        if let occupant = others.first {
            throw NamespaceMigratorError.collision(job: job, occupant: occupant)
        }

        try fm.moveItem(at: source, to: dest)

        let manifestURL = dest.appendingPathComponent("addon.yaml")
        if var text = try? String(contentsOf: manifestURL, encoding: .utf8),
           let range = text.range(of: "id: \(job)")
        {
            text.replaceSubrange(range, with: "id: \(destId)")
            try? text.write(to: manifestURL, atomically: true, encoding: .utf8)
        }

        var config = try store.loadOrCreateDefaults()
        if let existing = config.addons[job] {
            config.addons[destId] = existing
            config.addons.removeValue(forKey: job)
            try store.save(config)
        }

        let oldState = paths.stateDir.appendingPathComponent(job)
        let newState = paths.stateDir.appendingPathComponent(destId)
        if fm.fileExists(atPath: oldState.path), !fm.fileExists(atPath: newState.path) {
            try? fm.moveItem(at: oldState, to: newState)
        }

        if let stateStore {
            var state = (try? stateStore.load()) ?? JugnuState()
            remapQualifiedIds(state: &state, fromAddon: job, toAddon: destId)
            try? stateStore.save(state)
        }
    }

    /// Recents/favorites use `addonId.commandId` (addon id may itself contain dots after namespace).
    public static func remapQualifiedIds(state: inout JugnuState, fromAddon: String, toAddon: String) {
        func remap(_ id: String) -> String? {
            if id == fromAddon { return toAddon }
            let prefix = fromAddon + "."
            if id.hasPrefix(prefix) {
                return toAddon + "." + String(id.dropFirst(prefix.count))
            }
            return nil
        }

        state.recentCommandIDs = state.recentCommandIDs.compactMap { id in
            remap(id) ?? id
        }
        // Dedupe preserving order
        var seen = Set<String>()
        state.recentCommandIDs = state.recentCommandIDs.filter { seen.insert($0).inserted }

        state.favoriteCommandIDs = state.favoriteCommandIDs.compactMap { id in
            remap(id) ?? id
        }
        seen.removeAll()
        state.favoriteCommandIDs = state.favoriteCommandIDs.filter { seen.insert($0).inserted }
    }
}
