import AppKit
import JugnuCore
import JugnuUI

@MainActor
enum TCCExplainerGate {
    static func ensureReady(
        addonName: String,
        permissions: [AddonPermission],
        shellHost: ShellHost,
        commandId: String
    ) async throws {
        let pending = PermissionsSet.sort(permissions.filter(\.isTCC))
            .filter { !TCCGrantStatus.isGranted($0) }
        for permission in pending {
            let ui = confirmPreTCCExplainerUI(addonName: addonName, permission: permission)
            let openSettings = await InstallDisclosurePresenter.confirm(
                ui: ui,
                shellHost: shellHost,
                commandId: commandId
            )
            guard openSettings else { throw TCCGateError.declined(permission) }
            if let url = TCCPrivacyURL.systemSettingsURL(for: permission) {
                NSWorkspace.shared.open(url)
            }
            throw TCCGateError.openedSettings(permission)
        }
    }
}
