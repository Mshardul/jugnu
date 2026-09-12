import AppKit
import JugnuCore
import JugnuUI

@MainActor
extension AppDelegate {
    func runDetailCommand(addonID: String, commandId: String) {
        guard let model else { return }
        let qualified = "\(addonID).\(commandId)"
        if let cmd = model.allCommands.first(where: { $0.qualifiedId == qualified }) {
            runCommand(cmd)
            return
        }
        model.statusMessage = "That command isn’t available."
    }

    func runPrimary(addonID: String) {
        guard let model else { return }
        let root = model.paths.addonsDir.appendingPathComponent(addonID)
        guard let primary = (try? ManifestLoader.load(from: root))?.primaryCommand?.id else {
            model.statusMessage = "This addon has no default action."
            return
        }
        runDetailCommand(addonID: addonID, commandId: primary)
    }

    func addonConfigState(for addonID: String) -> (
        schema: [AddonConfigField],
        values: [String: JSONValue],
        error: String?
    ) {
        guard let model else { return ([], [:], nil) }
        let root = model.paths.addonsDir.appendingPathComponent(addonID)
        guard let manifest = try? ManifestLoader.load(from: root) else {
            return ([], [:], nil)
        }
        do {
            let values = try AddonConfigResolver.resolve(
                schema: manifest.config,
                fileURL: model.paths.addonConfigFile(id: addonID)
            )
            return (manifest.config, values, nil)
        } catch let error as AddonConfigError {
            return (
                manifest.config,
                [:],
                "Config for \"\(manifest.name)\" is invalid: \(AddonConfigResolver.reason(for: error))."
            )
        } catch {
            return (manifest.config, [:], UserFacingError.message(for: error))
        }
    }

    func saveAddonConfigValue(addonID: String, key: String, value: JSONValue) {
        guard let model else { return }
        let root = model.paths.addonsDir.appendingPathComponent(addonID)
        guard let manifest = try? ManifestLoader.load(from: root) else { return }
        let file = model.paths.addonConfigFile(id: addonID)
        var values = (try? AddonConfigResolver.resolve(schema: manifest.config, fileURL: file)) ?? [:]
        for field in manifest.config where values[field.key] == nil {
            values[field.key] = field.default
        }
        values[key] = value
        try? AddonConfigResolver.writeFile(schema: manifest.config, values: values, to: file)
        renderCurrentTop(model: model)
    }

    func openAddonConfigFile(addonID: String) {
        guard let model else { return }
        let file = model.paths.addonConfigFile(id: addonID)
        let parent = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            let root = model.paths.addonsDir.appendingPathComponent(addonID)
            if let manifest = try? ManifestLoader.load(from: root) {
                try? AddonConfigResolver.writeFile(
                    schema: manifest.config,
                    values: Dictionary(uniqueKeysWithValues: manifest.config.map { ($0.key, $0.default) }),
                    to: file
                )
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    func resetAddonConfigFile(addonID: String) {
        guard let model else { return }
        let root = model.paths.addonsDir.appendingPathComponent(addonID)
        guard let manifest = try? ManifestLoader.load(from: root) else { return }
        try? AddonConfigResolver.writeFile(
            schema: manifest.config,
            values: Dictionary(uniqueKeysWithValues: manifest.config.map { ($0.key, $0.default) }),
            to: model.paths.addonConfigFile(id: addonID)
        )
    }

    func presentAddonConfigRecovery(addonID: String, name: String, error: AddonConfigError) {
        let alert = NSAlert()
        alert.messageText = "Config for \"\(name)\" is invalid"
        alert.informativeText = AddonConfigResolver.reason(for: error)
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openAddonConfigFile(addonID: addonID)
        case .alertSecondButtonReturn:
            resetAddonConfigFile(addonID: addonID)
        default:
            break
        }
    }

    func runCommand(_ cmd: IndexedCommand) {
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
            let manifest = try ManifestLoader.load(from: cmd.addonRoot)
            do {
                _ = try AddonRunner.resolveConfig(manifest: manifest, paths: model.paths)
            } catch let error as AddonConfigError {
                presentAddonConfigRecovery(addonID: cmd.addonId, name: manifest.name, error: error)
                playCommandSound(success: false)
                return
            }
            let invocation = try model.runInvocation(for: cmd)
            let gated = Self.tccGated(
                invocation: invocation,
                addonName: manifest.name,
                permissions: manifest.permissions,
                shellHost: shellHost,
                commandId: cmd.qualifiedId
            )
            let task = Task { @MainActor [weak self] in
                await CommandInvoke.run(
                    host: shellHost,
                    commandId: cmd.qualifiedId,
                    onScreen: screen,
                    execute: gated.execute,
                    followUp: gated.followUp
                )
                if self?.inFlightInvoke?.key == key {
                    self?.inFlightInvoke = nil
                }
                // still on launcher = toast-only result, no follow-up pushed; close
                if shellHost.stack.top.preset == .launcher {
                    shellHost.hide()
                }
            }
            inFlightInvoke = (key: key, task: task)
        } catch let error as AddonConfigError {
            if let manifest = try? ManifestLoader.load(from: cmd.addonRoot) {
                presentAddonConfigRecovery(addonID: cmd.addonId, name: manifest.name, error: error)
            } else {
                model.statusMessage = UserFacingError.message(for: error)
            }
            playCommandSound(success: false)
        } catch {
            model.statusMessage = UserFacingError.message(for: error)
            playCommandSound(success: false)
        }
    }

    func runClockCommand(
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
        let manifest = try ManifestLoader.load(from: indexed.addonRoot)
        let gated = Self.tccGated(
            invocation: invocation,
            addonName: manifest.name,
            permissions: manifest.permissions,
            shellHost: shellHost,
            commandId: indexed.qualifiedId
        )
        let succeeded = await CommandInvoke.run(
            host: shellHost,
            commandId: indexed.qualifiedId,
            onScreen: screen,
            execute: gated.execute,
            followUp: gated.followUp
        )
        guard succeeded else { throw ClockInvocationError.commandFailed }
    }

    static func tccGated(
        invocation: (
            execute: () async throws -> RunResponse,
            followUp: (RunRequest) async throws -> RunResponse
        ),
        addonName: String,
        permissions: [AddonPermission],
        shellHost: ShellHost,
        commandId: String
    ) -> (
        execute: () async throws -> RunResponse,
        followUp: (RunRequest) async throws -> RunResponse
    ) {
        let ensure: () async throws -> Void = {
            try await TCCExplainerGate.ensureReady(
                addonName: addonName,
                permissions: permissions,
                shellHost: shellHost,
                commandId: commandId
            )
        }
        return (
            execute: {
                try await ensure()
                return try await invocation.execute()
            },
            followUp: { request in
                try await ensure()
                return try await invocation.followUp(request)
            }
        )
    }
}

enum ClockInvocationError: Error {
    case unavailable
    case commandNotFound
    case commandFailed
}
