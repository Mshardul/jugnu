import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@main
struct JugnuMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var model: AppModel?
    private var shellHost: ShellHost?
    private var clockHost: ClockHost?
    private var processHost: AddonProcessHost?
    private var hotkey: HotkeyController?
    private var firstRun: FirstRunWindowController?
    private var catalogViewModel: BrowseCatalogViewModel?
    private var inFlightInvoke: (key: CommandKey, task: Task<Void, Never>)?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var reaper: AddonReaper?
    private var launchGuard: LaunchGuard?
    private var inRecovery = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !ScreenshotMode.isActive, yieldToRunningInstance() { return }

        let paths: JugnuPaths
        if ScreenshotMode.isActive, let shot = ScreenshotMode.makePaths() {
            paths = shot
        } else {
            paths = JugnuPaths()
        }

        let log = LifecycleLog(fileURL: paths.lifecycleLogFile)
        let configState = ConfigStore(paths: paths).inspect()
        let guardFile = LaunchGuard(fileURL: paths.crashCounterFile)
        if !ScreenshotMode.isActive {
            guardFile.recordAttempt()
        }
        launchGuard = guardFile

        let decision = LaunchStart.decide(
            safeMode: guardFile.shouldEnterSafeMode,
            configSyntaxError: configState.isSyntaxError
        )

        let model = AppModel(paths: paths, loadAddons: decision == .normal)
        self.model = model
        let processHost = AddonProcessHost(log: log)
        self.processHost = processHost
        model.processHost = processHost
        model.shellIdentity = ShellIdentity.current()

        let reaper = AddonReaper(paths: paths, host: processHost, log: log)
        self.reaper = reaper

        switch decision {
        case .recovery(let reason):
            enterRecovery(
                reason: reason,
                model: model,
                log: log,
                reaper: reaper,
                strikeCount: guardFile.count
            )
            return
        case .normal:
            break
        }

        reaper.reap(mode: .normal)
        model.bootstrap()

        let shellHost = ShellHost()
        self.shellHost = shellHost

        let clockHost = ClockHost(paths: model.paths) { [weak model] message in
            model?.statusMessage = message
        }
        self.clockHost = clockHost
        clockHost.start(
            markerDir: model.paths.stateRunDir,
            shellIdentity: model.shellIdentity
        ) { [weak self] addon, command, timerID in
            guard let self else { throw ClockInvocationError.unavailable }
            try await self.runClockCommand(
                addon: addon,
                command: command,
                timerID: timerID
            )
        }

        let menuBar = MenuBarController(
            onOpenPalette: { [weak self] in self?.invokeShell() },
            onPreferences: { [weak self] in self?.pushSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        self.menuBar = menuBar

        let hotkey = HotkeyController(model: model) { [weak self] in
            self?.invokeShell()
        }
        self.hotkey = hotkey
        hotkey.registerFromConfig()

        DistributedNotificationCenter.default().addObserver(
            forName: SingleInstance.openPaletteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.invokeShell() }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.processHost?.killAll()
                self?.shellHost?.dismissDetachedPanels()
            }
        }
        wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reaper?.reap(mode: .normal) }
        }

        if !model.state.firstRunCompleted, !ScreenshotMode.isActive {
            let first = FirstRunWindowController(model: model) { [weak self, weak hotkey] in
                hotkey?.registerFromConfig()
                self?.firstRun = nil
            }
            self.firstRun = first
            first.show()
        }

        launchGuard?.markCleanLaunch()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard processHost?.hasLiveJob() == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Quit Jugnu?"
        alert.informativeText = "A long-running addon job is still working. Quitting stops it."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() != .alertFirstButtonReturn {
            return .terminateCancel
        }
        processHost?.killAll()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        clockHost?.stop()
        processHost?.killAll()
        reaper?.reap(mode: inRecovery ? .degraded : .normal)
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        if let sleepObserver {
            workspaceCenter.removeObserver(sleepObserver)
        }
        if let wakeObserver {
            workspaceCenter.removeObserver(wakeObserver)
        }
    }

    private func enterRecovery(
        reason: RecoveryReason,
        model: AppModel,
        log: LifecycleLog,
        reaper: AddonReaper,
        strikeCount: Int
    ) {
        inRecovery = true
        ThemeStore.shared.config = JugnuConfig().theme
        model.daemonAgents.bootoutAllJugnuAgents(paths: model.paths)
        log.recordNow(
            event: "safe_mode",
            reason: reason == .malformedConfig ? "yaml" : "crash-loop",
            strikeCount: strikeCount
        )
        reaper.reap(mode: .degraded)
        menuBar = MenuBarController(
            onOpenPalette: {},
            onPreferences: {},
            onQuit: { NSApp.terminate(nil) },
            recovery: RecoveryMenuActions(
                onResetConfig: { [weak self] in self?.recoveryResetConfig() },
                onOpenConfig: { [weak self] in self?.recoveryOpenConfig() },
                onDisableAllAddons: { [weak self] in self?.recoveryDisableAddons() },
                onTryAgain: { [weak self] in self?.recoveryTryAgain() }
            )
        )
    }

    private func recoveryResetConfig() {
        guard let model else { return }
        try? model.store.save(JugnuConfig())
        recoveryTryAgain()
    }

    private func recoveryOpenConfig() {
        guard let model else { return }
        let file = model.paths.configFile
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            try? model.store.save(JugnuConfig())
        }
        NSWorkspace.shared.open(file)
    }

    private func recoveryDisableAddons() {
        guard let model else { return }
        var config = (try? model.store.load()) ?? JugnuConfig()
        for id in model.installedAddonIDs() {
            config.addons[id] = AddonConfig(enabled: false)
        }
        try? model.store.save(config)
        recoveryTryAgain()
    }

    private func recoveryTryAgain() {
        launchGuard?.markCleanLaunch()
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    // Another Jugnu is already up: ask it to open the palette, then quit before touching the hotkey or menu bar.
    private func yieldToRunningInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let selfPID = Int(ProcessInfo.processInfo.processIdentifier)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map {
            RunningInstance(pid: Int($0.processIdentifier), launchDate: $0.launchDate)
        }
        guard SingleInstance.shouldYield(running: running, selfPID: selfPID) else { return false }
        DistributedNotificationCenter.default().postNotificationName(
            SingleInstance.openPaletteNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        NSApp.terminate(nil)
        return true
    }

    /// Invoke hotkey / Open Palette: not on launcher (or not visible) -> home; on launcher -> close.
    private func invokeShell() {
        guard let model, let shellHost else { return }
        model.refreshIndex()
        let mouse = NSEvent.mouseLocation
        let frames = NSScreen.screens.map(\.frame)
        let screen: NSScreen
        if let idx = PalettePlacement.screenIndex(frames: frames, mouse: mouse),
           NSScreen.screens.indices.contains(idx) {
            screen = NSScreen.screens[idx]
        } else {
            screen = NSScreen.main ?? NSScreen.screens[0]
        }
        switch decideInvokeOutcome(stack: shellHost.stack, isVisible: shellHost.isVisible) {
        case .close:
            tearDownInFlight()
            shellHost.hide()
        case .showHome:
            syncCatalogSnapshot()
            ensurePanelIfNeeded(model: model)
            shellHost.goHome()
            renderCurrentTop(model: model)
            shellHost.morphFrame(to: .launcher, compactLauncher: true, on: screen)
            shellHost.orderFront()
            shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
        }
    }

    /// Esc / Cmd+W: pop one level if not at root; dismiss (hide, empty stack) if already at root.
    private func popOrDismiss() {
        guard let model, let shellHost else { return }
        tearDownInFlight()
        if shellHost.stack.isAtRoot {
            shellHost.hide()
            return
        }
        syncCatalogSnapshot()
        shellHost.popTop()
        renderCurrentTop(model: model)
        let screen = shellHost.currentScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let compact = shellHost.stack.top.preset == .launcher
        shellHost.morphFrame(to: shellHost.stack.top.preset, compactLauncher: compact, on: screen)
    }

    /// Genuine click outside the app's own windows. Dismisses unless the current view type ignores it.
    private func dismissFromClickOutside() {
        guard let shellHost, shellHost.dismissesOnOutsideClick else { return }
        tearDownInFlight()
        shellHost.hide()
    }

    // Fire-and-forget so a dismiss never waits on process teardown.
    private func tearDownInFlight() {
        guard let inFlight = inFlightInvoke else { return }
        inFlight.task.cancel()
        processHost?.killTracked(key: inFlight.key)
        inFlightInvoke = nil
    }

    /// Pushing `settings` from `launcher` is a push (child); replacing `catalog` with `settings` is a replace (sibling).
    private func pushSettings() {
        guard let model, let shellHost else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        syncCatalogSnapshot()
        ensurePanelIfNeeded(model: model)
        let entry = ShellStackEntry(.settings(scroll: 0, focusedControlID: nil))
        if shellHost.stack.top.preset == .catalog {
            shellHost.replace(entry)
        } else {
            shellHost.push(entry)
        }
        renderCurrentTop(model: model)
        shellHost.morphFrame(to: .settings, compactLauncher: false, on: screen)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
    }

    /// Pushing `catalog` from `launcher` is a push (child); replacing `settings` with `catalog` is a replace (sibling).
    private func pushCatalog() {
        guard let model, let shellHost else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        ensurePanelIfNeeded(model: model)
        let entry = ShellStackEntry(.catalog(
            category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil
        ))
        if shellHost.stack.top.preset == .settings {
            shellHost.replace(entry)
        } else {
            shellHost.push(entry)
        }
        renderCurrentTop(model: model)
        shellHost.morphFrame(to: .catalog, compactLauncher: false, on: screen)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
    }

    /// Pushing `detail` from `catalog` is a push (child); idempotent re-push of the same addon just refocuses.
    private func pushDetail(addonID: String) {
        guard let model, let shellHost else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        syncCatalogSnapshot()
        shellHost.push(ShellStackEntry(.detail(addonID: addonID)))
        renderCurrentTop(model: model)
        shellHost.morphFrame(to: .detail, compactLauncher: false, on: screen)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
    }

    private func ensurePanelIfNeeded(model: AppModel) {
        guard let shellHost else { return }
        shellHost.ensurePanel(
            initialContent: PaletteView(
                model: model,
                favorites: model.topFavorites(limit: 5),
                onRun: { [weak self] cmd in self?.runCommand(cmd) },
                onClose: { [weak shellHost] in shellHost?.hide() },
                onOpenBrowseCatalog: { [weak self] in self?.pushCatalog() },
                onOpenPreferences: { [weak self] in self?.pushSettings() },
                onRunShellNative: { [weak self] cmd in self?.runShellNative(cmd) },
                onReorderFavorite: { [weak self] from, to in self?.model?.moveFavorite(from: from, to: to) },
                onRemoveFavorite: { [weak self] cmd in self?.model?.removeFavorite(qualifiedId: cmd.qualifiedId) }
            ),
            size: ShellPreset.launcher.size(compactLauncher: false)
        )
    }

    private func runShellNative(_ cmd: ShellNativeCommand) {
        switch cmd.kind {
        case .browseAddons: pushCatalog()
        case .preferences: pushSettings()
        }
    }

    /// Central dispatch: maps `stack.top.preset` to the concrete view hosted in the panel.
    /// Every subsequent task (11+) extends this with one more case.
    private func renderCurrentTop(model: AppModel) {
        guard let shellHost else { return }
        shellHost.setOnCancel { [weak self] in self?.popOrDismiss() }
        switch shellHost.stack.top.preset {
        case .launcher:
            guard case .launcher(let query, _, _) = shellHost.stack.top.state else { return }
            shellHost.setContent(PaletteView(
                model: model,
                favorites: model.topFavorites(limit: 5),
                initialQuery: query,
                onRun: { [weak self] cmd in self?.runCommand(cmd) },
                onClose: { [weak shellHost] in shellHost?.hide() },
                onOpenBrowseCatalog: { [weak self] in self?.pushCatalog() },
                onOpenPreferences: { [weak self] in self?.pushSettings() },
                onRunShellNative: { [weak self] cmd in self?.runShellNative(cmd) },
                onStateChange: { [weak shellHost] state in shellHost?.updateTopState(state) },
                onReorderFavorite: { [weak self] from, to in self?.model?.moveFavorite(from: from, to: to) },
                onRemoveFavorite: { [weak self] cmd in self?.model?.removeFavorite(qualifiedId: cmd.qualifiedId) }
            ))
        case .settings:
            shellHost.setContent(PrefsView(model: model, shellHost: shellHost, onOpenCatalog: { [weak self] in self?.pushCatalog() }))
        case .catalog:
            let vm = catalogViewModel(model: model)
            shellHost.setContent(BrowseCatalogView(
                viewModel: vm,
                onSelectCard: { [weak self] addonID in self?.pushDetail(addonID: addonID) }
            ))
        case .detail:
            guard case .detail(let addonID) = shellHost.stack.top.state else { return }
            let vm = catalogViewModel(model: model)
            if let entry = vm.entries.first(where: { $0.id == addonID }) {
                shellHost.setContent(AddonDetailView(
                    entry: entry,
                    isInstalled: vm.isInstalled(entry.id),
                    isEnabled: vm.isEnabled(entry.id),
                    isInstalling: vm.installingIDs.contains(entry.id),
                    onInstall: { Task { await vm.install(entry) } },
                    onEnabledChange: { vm.setEnabled(entry.id, enabled: $0) },
                    onUninstall: { vm.uninstall(id: entry.id, name: entry.name) },
                    onClose: { [weak self] in self?.popOrDismiss() }
                ))
            }
        case .confirm, .list, .form:
            shellHost.renderFollowUpContent()
        }
    }

    /// Lazily builds (once) and reuses the catalog's view model so entries/filters survive push/pop.
    private func catalogViewModel(model: AppModel) -> BrowseCatalogViewModel {
        if let catalogViewModel { return catalogViewModel }
        guard let shellHost else { preconditionFailure("catalogViewModel(model:) requires shellHost to be set") }
        let vm = BrowseCatalogViewModel(model: model, shellHost: shellHost)
        catalogViewModel = vm
        return vm
    }

    /// Keeps `stack.top`'s `.catalog` snapshot (spec §7) mirroring the live view model's
    /// category/subcategory/tags/query. No-op unless catalog is actually the current top and its
    /// view model has been built. The view model's own @Published state (not this snapshot) is what
    /// actually makes catalog survive push/pop — see Task 10 notes — but the snapshot still needs to
    /// be accurate for anything that inspects the stack directly. Call this right before leaving
    /// catalog (pushing a child, replacing with a sibling, or popping away) so the snapshot reflects
    /// what the user was looking at, not whatever it was when catalog was first pushed. Scroll
    /// position and selected-card-id aren't tracked by the view model yet, so those two fields stay
    /// at their last-pushed value rather than being kept live.
    private func syncCatalogSnapshot() {
        guard let shellHost, let catalogViewModel, shellHost.stack.top.preset == .catalog else { return }
        shellHost.updateTopState(.catalog(
            category: catalogViewModel.selection.category,
            subcategory: catalogViewModel.selection.subcategory,
            tags: catalogViewModel.selectedTags,
            query: catalogViewModel.searchText,
            scroll: 0,
            selectedCardID: nil
        ))
    }

    private func runCommand(_ cmd: IndexedCommand) {
        guard let model, let shellHost else { return }
        guard let screen = shellHost.currentScreen ?? NSScreen.main else { return }
        shellHost.onCancelFollowUp = { [weak self] in self?.popOrDismiss() }
        let key = CommandKey(addonID: cmd.addonId, commandID: cmd.commandId)
        let klass = (try? ManifestLoader.load(from: cmd.addonRoot))?.effectiveLifecycle(commandId: cmd.commandId) ?? .oneshot
        if klass == .job {
            shellHost.showJobProgress(startedAt: Date(), onScreen: screen) { [weak self] in
                self?.processHost?.killTracked(key: key)
                self?.popOrDismiss()
            }
        }
        do {
            let invocation = try model.runInvocation(for: cmd)
            let task = Task { @MainActor [weak self] in
                await CommandInvoke.run(
                    host: shellHost,
                    commandId: cmd.qualifiedId,
                    onScreen: screen,
                    execute: invocation.execute,
                    followUp: invocation.followUp
                )
                if self?.inFlightInvoke?.key == key {
                    self?.inFlightInvoke = nil
                }
                // A follow-up (confirm/list/form) got pushed onto the stack; leave the panel open.
                // No follow-up (toast-only) means we're still on launcher — close per spec.
                if shellHost.stack.top.preset == .launcher {
                    shellHost.hide()
                }
            }
            inFlightInvoke = (key: key, task: task)
        } catch {
            model.statusMessage = UserFacingError.message(for: error)
            playCommandSound(success: false)
        }
    }

    private func runClockCommand(
        addon: String,
        command: String,
        timerID: String
    ) async throws {
        guard let model, let shellHost else { throw ClockInvocationError.unavailable }
        model.refreshIndex()
        guard let indexed = model.allCommands.first(where: {
            $0.addonId == addon && $0.commandId == command
        }) else {
            throw ClockInvocationError.commandNotFound
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw ClockInvocationError.unavailable
        }
        let invocation = try model.runInvocation(
            for: indexed,
            args: ["timerId": .string(timerID)]
        )
        let succeeded = await CommandInvoke.run(
            host: shellHost,
            commandId: indexed.qualifiedId,
            onScreen: screen,
            execute: invocation.execute,
            followUp: invocation.followUp
        )
        guard succeeded else { throw ClockInvocationError.commandFailed }
    }
}

private enum ClockInvocationError: Error {
    case unavailable
    case commandNotFound
    case commandFailed
}
