import SwiftUI

public struct AddonActionRow: View {
    let isInstalled: Bool
    let isEnabled: Bool
    let isInstalling: Bool
    let theme: JugnuThemeColors
    let onInstall: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onUninstall: () -> Void

    public init(
        isInstalled: Bool, isEnabled: Bool, isInstalling: Bool, theme: JugnuThemeColors,
        onInstall: @escaping () -> Void, onEnabledChange: @escaping (Bool) -> Void,
        onUninstall: @escaping () -> Void
    ) {
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.isInstalling = isInstalling
        self.theme = theme
        self.onInstall = onInstall
        self.onEnabledChange = onEnabledChange
        self.onUninstall = onUninstall
    }

    public var body: some View {
        HStack {
            if isInstalled {
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
