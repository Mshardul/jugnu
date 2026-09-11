import JugnuCore
import SwiftUI

public struct AddonActionRow: View {
    let isInstalled: Bool
    let isEnabled: Bool
    let isInstalling: Bool
    let updateAvailable: Bool
    let primary: String?
    let theme: JugnuThemeColors
    let onInstall: () -> Void
    let onUpdate: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onUninstall: () -> Void
    let onOpen: () -> Void

    public init(
        isInstalled: Bool,
        isEnabled: Bool,
        isInstalling: Bool,
        updateAvailable: Bool = false,
        primary: String? = nil,
        theme: JugnuThemeColors,
        onInstall: @escaping () -> Void,
        onUpdate: @escaping () -> Void = {},
        onEnabledChange: @escaping (Bool) -> Void,
        onUninstall: @escaping () -> Void,
        onOpen: @escaping () -> Void = {}
    ) {
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.isInstalling = isInstalling
        self.updateAvailable = updateAvailable
        self.primary = primary
        self.theme = theme
        self.onInstall = onInstall
        self.onUpdate = onUpdate
        self.onEnabledChange = onEnabledChange
        self.onUninstall = onUninstall
        self.onOpen = onOpen
    }

    public var body: some View {
        HStack {
            if isInstalled {
                if AddonPrimaryAction.shouldShowOpen(isInstalled: isInstalled, isEnabled: isEnabled, primary: primary) {
                    Button("Open", action: onOpen)
                        .tint(theme.accent)
                }
                if updateAvailable {
                    if isInstalling {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Updating…")
                        }
                        .foregroundStyle(theme.textSecondary)
                    } else {
                        Button("Update", action: onUpdate)
                            .tint(theme.accent)
                    }
                }
                Button(isEnabled ? "Disable" : "Enable") {
                    onEnabledChange(!isEnabled)
                }
                .tint(isEnabled ? theme.error : theme.accent)
                Button("Uninstall", action: onUninstall)
                    .tint(theme.error)
            } else if isInstalling {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small)
                    Text("Installing…")
                }
                .foregroundStyle(theme.textSecondary)
            } else {
                Button("Install", action: onInstall)
                    .tint(theme.accent)
            }
        }
    }
}
