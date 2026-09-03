import AppKit
import Foundation
import JugnuCore

enum DaemonAgentsError: Error, Equatable {
    case notFirstParty(String)
}

protocol DaemonLaunchctl {
    func run(_ arguments: [String]) throws
}

struct ProcessLaunchctl: DaemonLaunchctl {
    func run(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
    }
}

struct DaemonAgents {
    static var firstPartyDaemonIDs: Set<String> { FirstPartyDaemons.ids }

    var launchctl: DaemonLaunchctl
    var uid: uid_t

    init(launchctl: DaemonLaunchctl = ProcessLaunchctl(), uid: uid_t = getuid()) {
        self.launchctl = launchctl
        self.uid = uid
    }

    func bootstrap(
        addonID: String,
        commandID: String,
        block: DaemonBlock,
        addonRoot: URL,
        paths: JugnuPaths,
        shellIdentity: AddonRunner.ShellIdentity
    ) throws {
        guard FirstPartyDaemons.ids.contains(addonID) else {
            throw DaemonAgentsError.notFirstParty(addonID)
        }
        let label = FirstPartyDaemons.launchdLabel(addonID: addonID, commandID: commandID)
        let plist = try writePlist(
            label: label,
            addonID: addonID,
            commandID: commandID,
            block: block,
            addonRoot: addonRoot,
            paths: paths,
            shellIdentity: shellIdentity
        )
        try FileManager.default.createDirectory(at: paths.launchAgentsDir, withIntermediateDirectories: true)
        try launchctl.run(["bootstrap", "gui/\(uid)", plist.path])
    }

    func bootout(addonID: String, commandID: String, paths: JugnuPaths) {
        let label = FirstPartyDaemons.launchdLabel(addonID: addonID, commandID: commandID)
        let plist = paths.launchAgentsDir.appendingPathComponent("\(label).plist")
        try? launchctl.run(["bootout", "gui/\(uid)/\(label)"])
        try? FileManager.default.removeItem(at: plist)
    }

    func syncEnabled(manifest: AddonManifest, addonRoot: URL, paths: JugnuPaths, shellIdentity: AddonRunner.ShellIdentity) throws {
        for command in manifest.commands
            where manifest.effectiveLifecycle(commandId: command.id) == .daemon
        {
            guard let block = command.daemon else { continue }
            try bootstrap(
                addonID: manifest.id,
                commandID: command.id,
                block: block,
                addonRoot: addonRoot,
                paths: paths,
                shellIdentity: shellIdentity
            )
        }
    }

    func bootoutAll(manifest: AddonManifest, paths: JugnuPaths) {
        for command in manifest.commands
            where manifest.effectiveLifecycle(commandId: command.id) == .daemon
        {
            bootout(addonID: manifest.id, commandID: command.id, paths: paths)
        }
    }

    func bootoutAllJugnuAgents(paths: JugnuPaths) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: paths.launchAgentsDir,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in items where url.pathExtension == "plist" {
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("com.jugnu.") else { continue }
            try? launchctl.run(["bootout", "gui/\(uid)/\(name)"])
            try? fm.removeItem(at: url)
        }
    }

    func writePlist(
        label: String,
        addonID: String,
        commandID: String,
        block: DaemonBlock,
        addonRoot: URL,
        paths: JugnuPaths,
        shellIdentity: AddonRunner.ShellIdentity
    ) throws -> URL {
        try FileManager.default.createDirectory(at: paths.launchAgentsDir, withIntermediateDirectories: true)
        let program = addonRoot.appendingPathComponent(block.program).path
        var args = [program]
        args.append(contentsOf: block.args ?? [])
        let keepAlive = block.keepAlive ?? true
        let stateDir = paths.stateDir.appendingPathComponent(addonID)
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": args,
            "RunAtLoad": true,
            "KeepAlive": keepAlive,
            "StandardOutPath": stateDir.appendingPathComponent("daemon.out.log").path,
            "StandardErrorPath": stateDir.appendingPathComponent("daemon.err.log").path,
            "EnvironmentVariables": [
                "JUGNU_ORIGIN": "\(addonID):\(commandID)",
                "JUGNU_SHELL_START_TS": String(shellIdentity.startTS),
            ],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        let url = paths.launchAgentsDir.appendingPathComponent("\(label).plist")
        try data.write(to: url, options: .atomic)
        return url
    }
}

@MainActor
enum DisableWhileTracked {
    static func proceed(
        addonID: String,
        host: AddonProcessHost?,
        prompt: ((String) -> Bool)? = nil
    ) -> Bool {
        let ask = prompt ?? { DisableWhileTracked.appKitPrompt($0) }
        guard let host, host.hasTracked(addonID: addonID) else { return true }
        guard ask(addonID) else { return false }
        host.killTracked(addonID: addonID)
        return true
    }

    static func appKitPrompt(_ addonID: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Stop this addon’s running work?"
        alert.informativeText = "“\(addonID)” is still running. Disable or uninstall will stop it."
        alert.addButton(withTitle: "Stop and continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
