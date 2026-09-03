import AppKit
import JugnuCore
import JugnuUI

@MainActor
enum AddonUninstallPresenter {
    static func present(id: String, name: String, model: AppModel, shellHost: ShellHost, onDone: @escaping () -> Void) {
        guard DisableWhileTracked.proceed(addonID: id, host: model.processHost) else { return }
        guard let screen = shellHost.currentScreen ?? NSScreen.main else { return }
        let commandId = "shell.uninstall.\(id)"
        shellHost.pushFollowUp(
            ui: confirmUninstallUI(name: name),
            commandId: commandId,
            trace: nil,
            onScreen: screen,
            followUp: { _ in
                try model.uninstall(id: id)
                onDone()
                return RunResponse(ok: true)
            }
        )
    }
}
