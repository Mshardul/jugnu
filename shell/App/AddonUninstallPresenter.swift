import JugnuCore
import JugnuUI

@MainActor
enum AddonUninstallPresenter {
    static func present(id: String, name: String, model: AppModel, onDone: @escaping () -> Void) {
        model.uiHost.presentConfirm(
            ui: confirmUninstallUI(name: name),
            commandId: "shell.uninstall.\(id)",
            onConfirm: {
                try model.uninstall(id: id)
                onDone()
            }
        )
    }
}
