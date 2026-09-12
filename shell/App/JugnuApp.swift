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
    var menuBar: MenuBarController?
    var model: AppModel?
    var shellHost: ShellHost?
    var clockHost: ClockHost?
    var processHost: AddonProcessHost?
    var hotkey: HotkeyController?
    var firstRun: FirstRunWindowController?
    var catalogViewModel: BrowseCatalogViewModel?
    var inFlightInvoke: (key: CommandKey, task: Task<Void, Never>)?
    var sleepObserver: NSObjectProtocol?
    var wakeObserver: NSObjectProtocol?
    var reaper: AddonReaper?
    var launchGuard: LaunchGuard?
    var inRecovery = false
    var keepCurrent: KeepCurrentCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !ScreenshotMode.isActive, yieldToRunningInstance() { return }

        let paths: JugnuPaths
        if ScreenshotMode.isActive, let shot = ScreenshotMode.makePaths() {
            paths = shot
        } else {
            paths = JugnuPaths()
        }
        AddonInstaller(paths: paths).recoverInstallOrphans()
        do {
            try NamespaceMigrator.migrateInstalledTree(
                paths: paths,
                store: ConfigStore(paths: paths),
                stateStore: StateStore(paths: paths)
            )
        } catch {
            // Collision or I/O — leave tree as-is; next launch retries remaining ids.
            NSLog("Namespace migration deferred: \(error.localizedDescription)")
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
            onQuit: { NSApp.terminate(nil) },
            onCheckForUpdates: { [weak self] in
                Task { await self?.keepCurrent?.checkManual() }
            }
        )
        self.menuBar = menuBar

        wireKeepCurrent(model: model, shellHost: shellHost)

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
                self?.pushCatalog()
            }
            self.firstRun = first
            first.show()
        }

        launchGuard?.markCleanLaunch()

        Task { [weak self] in
            await self?.keepCurrent?.checkOnLaunch()
        }
    }

    private func wireKeepCurrent(model: AppModel, shellHost: ShellHost) {
        let coordinator = KeepCurrentCoordinator(model: model, shellHost: shellHost)
        coordinator.preparePanel = { [weak self] in
            guard let self, let model = self.model else { return }
            self.ensurePanelIfNeeded(model: model)
            self.shellHost?.setOnCancel { [weak self] in self?.popOrDismiss() }
        }
        coordinator.onDismissConfirm = { [weak self] in self?.popOrDismiss() }
        coordinator.onApplyAppUpdate = { [weak self] staged in
            self?.applyStagedAppUpdate(staged)
        }
        keepCurrent = coordinator
    }

    private func applyStagedAppUpdate(_ stagedApp: URL) {
        guard let model, let processHost else { return }
        do {
            let script = try AppApplyHelper.write(
                dir: model.paths.appUpdateDir,
                pid: ProcessInfo.processInfo.processIdentifier,
                sourceApp: stagedApp,
                destApp: Bundle.main.bundleURL
            )
            processHost.killAll()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [script.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            NSApp.terminate(nil)
        } catch {
            let message = UserFacingError.message(for: AppUpdateError.helperSpawnFailed)
            model.statusMessage = message
            shellHost?.showToast(message: message, isError: true)
        }
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

    func popOrDismiss() {
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

    func dismissFromClickOutside() {
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
}

