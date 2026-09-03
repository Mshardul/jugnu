import AppKit
import Combine
import Foundation
import JugnuCore
import JugnuUI
import SwiftUI

@MainActor
final class AppModel: ObservableObject, PaletteModelProtocol {
    let paths: JugnuPaths
    let store: ConfigStore
    let stateStore: StateStore
    let installer: AddonInstaller
    let lifecycle: AddonLifecycle
    let runner: AddonRunner
    var processHost: AddonProcessHost?
    var shellIdentity: AddonRunner.ShellIdentity = .unknown
    var daemonAgents = DaemonAgents()
    private let loadAddons: Bool

    @Published var config: JugnuConfig
    @Published var state: JugnuState
    @Published var results: [IndexedCommand] = []
    @Published var lastHits: [SearchHit] = []
    @Published var statusMessage: String?

    private var index: CommandIndex

    init(paths: JugnuPaths = JugnuPaths(), loadAddons: Bool = true) {
        self.paths = paths
        self.loadAddons = loadAddons
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
    var hiddenShellCommands: Set<String> { config.shell.hiddenShellCommands }
    var shellNativeCommands: [ShellNativeCommand] {
        ShellNativeCommand.visible(hidden: config.shell.hiddenShellCommands)
    }

    func bootstrap() {
        guard loadAddons else {
            results = []
            lastHits = []
            ThemeStore.shared.config = JugnuConfig().theme
            return
        }
        refreshIndex()
        for id in installedAddonIDs() where config.addons[id]?.enabled == true {
            try? bootstrapDaemons(id: id)
        }
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

    func moveFavorite(from source: Int, to destination: Int) {
        state.moveFavorite(from: source, to: destination)
        try? stateStore.save(state)
        objectWillChange.send()
    }

    func removeFavorite(qualifiedId: String) {
        state.removeFavorite(qualifiedId: qualifiedId)
        try? stateStore.save(state)
        objectWillChange.send()
    }

    func topFavorites(limit: Int) -> [IndexedCommand] {
        Array(state.favoriteCommandIDs.compactMap { id in
            allCommands.first { $0.qualifiedId == id }
        }.prefix(limit))
    }

    func runInvocation(
        for command: IndexedCommand,
        args: [String: JSONValue] = [:]
    ) throws -> (
        execute: () async throws -> RunResponse,
        followUp: (RunRequest) async throws -> RunResponse
    ) {
        state.recordRecent(qualifiedId: command.qualifiedId)
        try? stateStore.save(state)
        let manifest = try ManifestLoader.load(from: command.addonRoot)
        let key = CommandKey(addonID: command.addonId, commandID: command.commandId)
        let markerDir = paths.stateRunDir
        let hardCeiling = TimeInterval(LatencyBudgets.oneshotHardCeilingMs) / 1000

        let klass = manifest.effectiveLifecycle(commandId: command.commandId)
        let onReinvoke = manifest.effectiveOnReinvoke(commandId: command.commandId)
        let oneshotTimeout = min(
            manifest.commands.first { $0.id == command.commandId }?.timeout ?? hardCeiling,
            hardCeiling
        )

        if klass == .daemon {
            let execute: () async throws -> RunResponse = {
                RunResponse(ok: true, message: "Running in the background.")
            }
            return (execute, { _ in RunResponse(ok: true, message: "Running in the background.") })
        }

        let execute: () async throws -> RunResponse = { [runner, installer, paths, processHost, shellIdentity, args] in
            try await installer.ensureHelpers(for: manifest)
            if klass == .job, let host = processHost {
                switch await host.prepareJobSpawn(key: key, mode: onReinvoke, programmatic: false) {
                case .reuse:
                    throw JobInvokeError.reuse
                case .stillStopping:
                    throw JobInvokeError.stillStopping
                case .spawn:
                    break
                }
            }
            let invokeUUID = UUID()
            let inv = try runner.spawn(
                manifest: manifest,
                addonRoot: command.addonRoot,
                commandId: command.commandId,
                args: args,
                invokeUUID: invokeUUID,
                lifecycleClass: klass,
                shellIdentity: shellIdentity,
                markerDir: markerDir,
                paths: paths
            )
            Self.track(inv, key: key, invokeUUID: invokeUUID, lifecycleClass: klass, host: processHost)
            let response: RunResponse
            if klass == .job {
                response = try await inv.waitForJobResponse()
            } else {
                response = try await inv.waitForResponse(timeout: oneshotTimeout)
            }
            return try response.resolvingView(
                commandView: command.defaultViewType,
                allowed: command.allowedViewTypes
            )
        }
        let followUp: (RunRequest) async throws -> RunResponse = {
            [runner, installer, paths, processHost, shellIdentity] request in
            try await installer.ensureHelpers(for: manifest)
            let env = try AddonRunner.helperEnvironment(manifest: manifest, paths: paths)
            let invokeUUID = UUID()
            let inv = try runner.spawn(
                addonRoot: command.addonRoot,
                entrypoint: manifest.entrypoint,
                request: request,
                extraEnvironment: env,
                origin: "\(command.addonId):\(command.commandId):\(invokeUUID.uuidString)",
                lifecycleClass: klass,
                shellIdentity: shellIdentity,
                markerDir: markerDir
            )
            Self.track(inv, key: key, invokeUUID: invokeUUID, lifecycleClass: klass, host: processHost)
            let response: RunResponse
            if klass == .job {
                response = try await inv.waitForJobResponse()
            } else {
                response = try await inv.waitForResponse(timeout: oneshotTimeout)
            }
            return try response.resolvingView(
                commandView: command.defaultViewType,
                allowed: command.allowedViewTypes
            )
        }
        return (execute, followUp)
    }

    private static func track(
        _ inv: RunningInvocation,
        key: CommandKey,
        invokeUUID: UUID,
        lifecycleClass: LifecycleClass,
        host: AddonProcessHost?
    ) {
        guard let host else { return }
        let entry = AddonProcessHost.Entry(
            invocation: inv,
            invocationTask: nil,
            lifecycleClass: lifecycleClass,
            startedAt: Date(),
            invokeUUID: invokeUUID,
            markerPath: inv.markerURL,
            phase: .live
        )
        host.register(key: key, entry: entry)
        let markerDir = inv.markerURL.deletingLastPathComponent()
        let pid = inv.process.processIdentifier
        inv.process.terminationHandler = { _ in
            RunMarker.delete(pid: pid, in: markerDir)
            Task { @MainActor in
                host.deregister(key: key, invokeUUID: invokeUUID)
            }
        }
    }

    func setEnabled(id: String, enabled: Bool) throws {
        let addonRoot = paths.addonsDir.appendingPathComponent(id)
        let manifest = try? ManifestLoader.load(from: addonRoot)
        if !enabled, let manifest {
            daemonAgents.bootoutAll(manifest: manifest, paths: paths)
        }
        try lifecycle.setEnabled(id: id, enabled: enabled)
        if enabled, let manifest {
            try daemonAgents.syncEnabled(
                manifest: manifest,
                addonRoot: addonRoot,
                paths: paths,
                shellIdentity: shellIdentity
            )
        }
        refreshIndex()
    }

    func uninstall(id: String) throws {
        let addonRoot = paths.addonsDir.appendingPathComponent(id)
        if let manifest = try? ManifestLoader.load(from: addonRoot) {
            daemonAgents.bootoutAll(manifest: manifest, paths: paths)
        }
        try lifecycle.uninstall(id: id)
        refreshIndex()
    }

    func bootstrapDaemons(id: String) throws {
        let addonRoot = paths.addonsDir.appendingPathComponent(id)
        guard let manifest = try? ManifestLoader.load(from: addonRoot) else { return }
        try daemonAgents.syncEnabled(
            manifest: manifest,
            addonRoot: addonRoot,
            paths: paths,
            shellIdentity: shellIdentity
        )
    }

    func installedAddonIDs() -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.addonsDir.path),
              let kids = try? fm.contentsOfDirectory(at: paths.addonsDir, includingPropertiesForKeys: nil)
        else { return [] }
        return kids.map(\.lastPathComponent).sorted()
    }

    func addonDisplayName(id: String) -> String {
        let root = paths.addonsDir.appendingPathComponent(id)
        return (try? ManifestLoader.load(from: root))?.name ?? id
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
                    let manifest = try ManifestLoader.load(from: root)
                    try await installer.ensureHelpers(for: manifest)
                    try? bootstrapDaemons(id: manifest.id)
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
            try? bootstrapDaemons(id: entry.id)
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
