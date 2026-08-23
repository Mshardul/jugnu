import AppKit
import Combine
import Foundation
import JugnuCore
import JugnuUI
import SwiftUI

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
    @Published var lastHits: [SearchHit] = []
    @Published var statusMessage: String?

    private var index: CommandIndex
    private var browseCatalogWindow: BrowseCatalogWindowController<BrowseCatalogViewModel>?

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
        publishTheme()
    }

    var allCommands: [IndexedCommand] { index.all }

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
            lastHits = index.searchHits("")
        } catch {
            statusMessage = UserFacingError.message(for: error)
        }
        publishTheme()
    }

    func search(_ query: String) -> [IndexedCommand] {
        let hits = index.searchHits(query)
        lastHits = hits
        results = hits.map(\.command)
        return results
    }

    func commandsForFirstView() -> [IndexedCommand] {
        switch config.palette.firstView {
        case .blank:
            return []
        case .recent:
            return state.recentCommandIDs.compactMap { id in index.all.first { $0.qualifiedId == id } }
        case .favorites:
            return state.favoriteCommandIDs.compactMap { id in index.all.first { $0.qualifiedId == id } }
        }
    }

    func toggleFavorite(qualifiedId: String) {
        state.toggleFavorite(qualifiedId: qualifiedId)
        try? stateStore.save(state)
        objectWillChange.send()
    }

    func isFavorite(qualifiedId: String) -> Bool {
        state.favoriteCommandIDs.contains(qualifiedId)
    }

    func run(_ command: IndexedCommand) async {
        statusMessage = nil
        if config.palette.firstView == .recent {
            state.recordRecent(qualifiedId: command.qualifiedId)
            try? stateStore.save(state)
        }
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
            statusMessage = UserFacingError.message(for: error)
            playCommandSound(success: false)
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

    func saveConfig(_ newConfig: JugnuConfig) throws {
        try store.save(newConfig)
        config = newConfig
        publishTheme()
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
                statusMessage = "Couldn’t reach the catalog, so the starter addons were copied from this Mac."
            }
        }
        if useCommandSpace {
            var c = try store.loadOrCreateDefaults()
            c.shell.hotkey = "cmd+space"
            try saveConfig(c)
        }
        state.firstRunCompleted = true
        try stateStore.save(state)
        refreshIndex()
    }

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
            statusMessage = "Installed \(ids.joined(separator: ", "))."
        } catch {
            statusMessage = UserFacingError.message(for: error)
        }
    }

    func openBrowseCatalog() {
        if let existing = browseCatalogWindow {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let vm = BrowseCatalogViewModel(model: self)
        let controller = BrowseCatalogWindowController(viewModel: vm)
        browseCatalogWindow = controller
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func publishTheme() {
        ThemeStore.shared.config = config.theme
        ThemeStore.shared.soundEnabled = config.sound
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
