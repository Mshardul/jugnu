import AppKit
import Foundation
import JugnuCore
import JugnuUI

@MainActor
final class KeepCurrentCoordinator {
    let model: AppModel
    let shellHost: ShellHost
    var onApplyAppUpdate: (URL) -> Void = { _ in }
    var preparePanel: () -> Void = {}
    var onDismissConfirm: () -> Void = {}

    private var addonCheckAfterAppLaterSilent: Bool?

    init(model: AppModel, shellHost: ShellHost) {
        self.model = model
        self.shellHost = shellHost
    }

    func checkOnLaunch() async {
        if await checkApp(silent: true) == .presented {
            return
        }
        await checkAddonsOnLaunch()
    }

    func checkManual() async {
        let app = await checkApp(silent: false)
        if app == .presented {
            return
        }
        let presentedAddons = await presentAddonBulk(silent: false)
        if app == .upToDate, !presentedAddons {
            model.statusMessage = "You’re up to date."
            shellHost.showToast(message: "You’re up to date.", isError: false)
        }
    }

    func checkAddonsOnLaunch() async {
        if AppUpdateSkip.shouldSkipAddonLaunchCheck(
            firstRunCompleted: model.state.firstRunCompleted,
            screenshotMode: ScreenshotMode.isActive
        ) {
            return
        }
        if !model.config.shell.keepAddonsCurrent {
            return
        }
        _ = await presentAddonBulk(silent: true)
    }

    func continueAfterAppLater() async {
        let silent = addonCheckAfterAppLaterSilent
        addonCheckAfterAppLaterSilent = nil
        guard let silent else { return }
        if silent {
            await checkAddonsOnLaunch()
        } else {
            let presented = await presentAddonBulk(silent: false)
            if !presented {
                model.statusMessage = "You’re up to date."
                shellHost.showToast(message: "You’re up to date.", isError: false)
            }
        }
    }

    static func destIsWritable(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isWritableKey]).isWritable) == true
    }

    private enum AppCheckOutcome {
        case presented
        case upToDate
        case other
    }

    private func checkApp(silent: Bool) async -> AppCheckOutcome {
        if silent {
            #if DEBUG
            let isDebug = true
            #else
            let isDebug = false
            #endif
            if AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: model.state.firstRunCompleted,
                screenshotMode: ScreenshotMode.isActive,
                bundlePath: Bundle.main.bundlePath,
                env: ProcessInfo.processInfo.environment,
                isDebug: isDebug
            ) {
                return .other
            }
            if !model.config.shell.keepAppCurrent {
                return .other
            }
        }
        guard let urlString = ShellConfig.appRegistryURL(from: model.config.shell.registryURL),
              let url = URL(string: urlString)
        else {
            if !silent {
                report(AppUpdateError.invalidRegistryURL)
            }
            return .other
        }
        let entry: AppRegistryEntry
        do {
            entry = try await RegistryClient().fetchAppRegistry(from: url)
        } catch {
            if !silent {
                report(error)
            }
            return .other
        }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        switch AppUpdate.availability(
            running: ShellVersion.current,
            registry: entry,
            osMajor: os.majorVersion,
            osMinor: os.minorVersion
        ) {
        case .upToDate:
            return .upToDate
        case .blockedMacOS(let required):
            if !silent {
                report(AppUpdateError.macOSTooOld(required: required))
            }
            return .other
        case .available(let available):
            let dest = Bundle.main.bundleURL
            if !Self.destIsWritable(dest) {
                if !silent {
                    report(AppUpdateError.destNotWritable)
                }
                return .other
            }
            presentAppConfirm(entry: available, silentAddonsAfterLater: silent)
            return .presented
        }
    }

    private func presentAppConfirm(entry: AppRegistryEntry, silentAddonsAfterLater: Bool) {
        addonCheckAfterAppLaterSilent = silentAddonsAfterLater
        preparePanel()
        guard let screen = shellHost.currentScreen ?? NSScreen.main else { return }
        shellHost.setOnCancel { [weak self] in
            self?.onDismissConfirm()
            Task { await self?.continueAfterAppLater() }
        }
        shellHost.onCancelFollowUp = { [weak self] in
            self?.onDismissConfirm()
            Task { await self?.continueAfterAppLater() }
        }
        shellHost.pushFollowUp(
            ui: confirmAppUpdateUI(version: entry.version, notes: entry.notes),
            commandId: "shell.app-update",
            trace: nil,
            onScreen: screen,
            followUp: { [weak self] _ in
                guard let self else { return RunResponse(ok: false) }
                self.addonCheckAfterAppLaterSilent = nil
                let staged = try await AppInstaller(paths: self.model.paths).stage(entry: entry)
                self.onApplyAppUpdate(staged)
                return RunResponse(ok: true)
            }
        )
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in
            self?.shellHost.hide()
            Task { await self?.continueAfterAppLater() }
        }
    }

    private func presentAddonBulk(silent: Bool) async -> Bool {
        guard let url = URL(string: model.config.shell.registryURL) else {
            if !silent {
                report(AppUpdateError.invalidRegistryURL)
            }
            return false
        }
        let catalog: [RegistryEntry]
        do {
            catalog = try await RegistryClient().fetch(from: url)
        } catch {
            if !silent {
                report(error)
            }
            return false
        }
        let outdated = AddonBulkUpdate.outdated(
            installed: model.installer.readInstalledAddonVersions(),
            catalog: catalog
        )
        guard !outdated.isEmpty else { return false }
        preparePanel()
        guard let screen = shellHost.currentScreen ?? NSScreen.main else { return false }
        shellHost.setOnCancel { [weak self] in self?.onDismissConfirm() }
        shellHost.onCancelFollowUp = { [weak self] in self?.onDismissConfirm() }
        shellHost.pushFollowUp(
            ui: confirmAddonBulkUI(count: outdated.count),
            commandId: "shell.addon-bulk-update",
            trace: nil,
            onScreen: screen,
            followUp: { [weak self] _ in
                guard let self else { return RunResponse(ok: false) }
                await self.applyAddonBulk(outdated: outdated, catalog: catalog)
                return RunResponse(ok: true, message: "Addons updated.")
            }
        )
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in
            self?.onDismissConfirm()
        }
        return true
    }

    private func applyAddonBulk(outdated: [RegistryEntry], catalog: [RegistryEntry]) async {
        for entry in outdated {
            guard ReplaceWhileTracked.proceed(
                addonID: entry.id,
                paths: model.paths,
                host: model.processHost
            ) else { continue }
            let preserveEnabled = model.config.addons[entry.id]?.enabled ?? false
            do {
                try await model.installer.install(
                    entry: entry,
                    enable: preserveEnabled,
                    catalog: catalog,
                    installedVersions: model.installer.readInstalledAddonVersions(),
                    confirmDependencies: { plan in
                        await MainActor.run { DependencyInstallDisclosure.confirm(plan) }
                    }
                )
                try? model.bootstrapDaemons(id: entry.id)
            } catch {
                if let installer = error as? AddonInstallerError,
                   case .dependencyDisclosureDeclined = installer
                {
                    continue
                }
                model.statusMessage = "\(entry.name) — \(UserFacingError.message(for: error))"
            }
        }
        model.refreshIndex()
    }

    private func report(_ error: Error) {
        let message = UserFacingError.message(for: error)
        model.statusMessage = message
        shellHost.showToast(message: message, isError: true)
    }
}
