import Combine
import Foundation
import JugnuCore
import JugnuUI

@MainActor
final class AppModel: ObservableObject {
    let paths: JugnuPaths
    let store: ConfigStore
    let stateStore: StateStore
    let installer: AddonInstaller
    let lifecycle: AddonLifecycle
    let runner: AddonRunner
    let uiHost = UIHostController()

    @Published var config: JugnuConfig
    @Published var state: JugnuState
    @Published var results: [IndexedCommand] = []
    @Published var statusMessage: String?

    private var index: CommandIndex

    init(paths: JugnuPaths = JugnuPaths()) {
        self.paths = paths
        self.store = ConfigStore(paths: paths)
        self.stateStore = StateStore(paths: paths)
        self.installer = AddonInstaller(paths: paths)
        self.lifecycle = AddonLifecycle(paths: paths, store: store)
        self.runner = AddonRunner()
        let loadedConfig = (try? store.loadOrCreateDefaults()) ?? JugnuConfig()
        let loadedState = (try? stateStore.load()) ?? JugnuState()
        self.config = loadedConfig
        self.state = loadedState
        self.index = CommandIndex(paths: paths, config: loadedConfig, extraAddonRoots: Self.devRoots())
    }

    func bootstrap() {
        refreshIndex()
    }

    func refreshIndex() {
        config = (try? store.loadOrCreateDefaults()) ?? config
        for root in Self.devRoots() {
            if let manifest = try? ManifestLoader.load(from: root),
               config.addons[manifest.id] == nil {
                config.addons[manifest.id] = AddonConfig(enabled: true)
            }
        }
        index = CommandIndex(paths: paths, config: config, extraAddonRoots: Self.devRoots())
        do {
            try index.rebuild()
            results = index.all
        } catch {
            statusMessage = String(describing: error)
        }
    }

    func search(_ query: String) -> [IndexedCommand] {
        let hits = index.search(query)
        results = hits
        return hits
    }

    func run(_ command: IndexedCommand) async {
        statusMessage = nil
        do {
            let manifest = try ManifestLoader.load(from: command.addonRoot)
            await CommandInvoke.run(
                host: uiHost,
                commandId: command.qualifiedId,
                defaultPattern: command.defaultUIPattern,
                title: command.title,
                execute: { [runner] in
                    try await Task.detached {
                        try runner.run(
                            manifest: manifest,
                            addonRoot: command.addonRoot,
                            commandId: command.commandId
                        )
                    }.value
                },
                followUp: { [runner] request in
                    try await Task.detached {
                        try runner.run(
                            addonRoot: command.addonRoot,
                            entrypoint: manifest.entrypoint,
                            request: request,
                            timeout: runner.timeoutSeconds
                        )
                    }.value
                }
            )
        } catch {
            statusMessage = String(describing: error)
        }
    }

    func setEnabled(id: String, enabled: Bool) throws {
        try lifecycle.setEnabled(id: id, enabled: enabled)
        refreshIndex()
    }

    func uninstall(id: String) throws {
        try lifecycle.uninstall(id: id)
        refreshIndex()
    }

    func installedAddonIDs() -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.addonsDir.path),
              let kids = try? fm.contentsOfDirectory(at: paths.addonsDir, includingPropertiesForKeys: nil)
        else { return [] }
        return kids.map(\.lastPathComponent).sorted()
    }

    func completeFirstRun(
        installRecommended: Bool,
        useCommandSpace: Bool,
        localAddonRoots: [URL]
    ) async throws {
        if installRecommended {
            do {
                try await installFromRegistry(ids: ShellConfig.recommendedAddonIDs)
            } catch {
                if localAddonRoots.isEmpty { throw error }
                for root in localAddonRoots {
                    try installer.installFromDirectory(url: root, enable: true)
                }
                statusMessage = "Registry install failed; used local addons. (\(error))"
            }
        }
        if useCommandSpace {
            var c = try store.loadOrCreateDefaults()
            c.shell.hotkey = "cmd+space"
            try store.save(c)
            config = c
        }
        state.firstRunCompleted = true
        try stateStore.save(state)
        refreshIndex()
    }

    /// Fetch catalog and install entries by id (sha256-verified zip download).
    @discardableResult
    func installFromRegistry(ids: [String]) async throws -> [String] {
        config = (try? store.loadOrCreateDefaults()) ?? config
        guard let url = URL(string: config.shell.registryURL) else {
            throw RegistryInstallError.invalidRegistryURL(config.shell.registryURL)
        }
        let entries = try await RegistryClient().fetch(from: url)
        let wanted = Set(ids)
        var installed: [String] = []
        for entry in entries where wanted.contains(entry.id) {
            guard !entry.url.isEmpty else { continue }
            try await installer.install(entry: entry, enable: true)
            installed.append(entry.id)
        }
        if installed.isEmpty {
            throw RegistryInstallError.noMatchingEntries(ids)
        }
        refreshIndex()
        return installed
    }

    func installRecommendedFromRegistry() async {
        statusMessage = nil
        do {
            let ids = try await installFromRegistry(ids: ShellConfig.recommendedAddonIDs)
            statusMessage = "Installed from registry: \(ids.joined(separator: ", "))"
        } catch {
            statusMessage = String(describing: error)
        }
    }

    private static func devRoots() -> [URL] {
        var roots: [URL] = []
        if let env = ProcessInfo.processInfo.environment["JUGNU_ADDON_PATH"], !env.isEmpty {
            for part in env.split(separator: ":") {
                roots.append(URL(fileURLWithPath: String(part)))
            }
        }
        return roots
    }
}

enum RegistryInstallError: Error, Equatable {
    case invalidRegistryURL(String)
    case noMatchingEntries([String])
}
