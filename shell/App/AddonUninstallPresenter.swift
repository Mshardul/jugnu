import AppKit
import JugnuCore
import JugnuUI

@MainActor
enum AddonUninstallPresenter {
    private static var activePanel: ConfirmPanel?

    static func present(id: String, name: String, model: AppModel, onDone: @escaping () -> Void) {
        let ui = confirmUninstallUI(name: name)
        let panel = ConfirmPanel(
            ui: ui,
            onConfirm: {
                do {
                    try model.uninstall(id: id)
                } catch {
                    model.statusMessage = UserFacingError.message(for: error)
                }
                activePanel?.orderOut(nil)
                activePanel = nil
                onDone()
            },
            onCancel: {
                activePanel?.orderOut(nil)
                activePanel = nil
            }
        )
        activePanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}
