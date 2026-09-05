import Foundation

/// Multi-package install: stage missing addons + helpers, commit helpers then addons, rollback created on failure.
public struct InstallTransaction: Sendable {
    public struct CreatedHelper: Equatable, Sendable {
        public var id: String
        public var version: String
        public init(id: String, version: String) {
            self.id = id
            self.version = version
        }
    }

    public private(set) var createdAddonIds: [String] = []
    public private(set) var createdHelpers: [CreatedHelper] = []

    private let paths: JugnuPaths
    private let store: ConfigStore

    public init(paths: JugnuPaths, store: ConfigStore) {
        self.paths = paths
        self.store = store
    }

    /// Promote already-staged addon package trees. `staged` maps id → staging directory.
    /// `enablePrimary` applies only to `primaryId`; other new addons get `enabled: false`.
    public mutating func commitAddons(
        staged: [String: URL],
        order: [String],
        primaryId: String,
        enablePrimary: Bool
    ) throws {
        let fm = FileManager.default
        for id in order {
            guard let staging = staged[id] else { continue }
            let live = paths.addonsDir.appendingPathComponent(id)
            let existed = fm.fileExists(atPath: live.path)
            try AtomicCommit.promote(staging: staging, live: live, trashParent: paths.addonsTrashDir)
            if !existed {
                createdAddonIds.append(id)
            }
            var config = try store.loadOrCreateDefaults()
            if id == primaryId {
                config.addons[id] = AddonConfig(enabled: enablePrimary)
            } else if config.addons[id] == nil {
                config.addons[id] = AddonConfig(enabled: false)
            }
            try store.save(config)
        }
    }

    public mutating func commitHelper(staging: URL, id: String, version: String) throws {
        let fm = FileManager.default
        let live = paths.helperRoot(id: id, version: version)
        let existed = fm.fileExists(atPath: live.path)
        try AtomicCommit.promote(staging: staging, live: live, trashParent: paths.helpersTrashDir)
        if !existed {
            createdHelpers.append(CreatedHelper(id: id, version: version))
        }
    }

    public func rollback() {
        let fm = FileManager.default
        for id in createdAddonIds.reversed() {
            let live = paths.addonsDir.appendingPathComponent(id)
            try? fm.removeItem(at: live)
            if var config = try? store.loadOrCreateDefaults() {
                config.addons.removeValue(forKey: id)
                try? store.save(config)
            }
        }
        for helper in createdHelpers.reversed() {
            let live = paths.helperRoot(id: helper.id, version: helper.version)
            try? fm.removeItem(at: live)
        }
    }
}
