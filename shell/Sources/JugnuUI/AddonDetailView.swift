import SwiftUI
import JugnuCore

public struct AddonDetailView: View {
    let entry: RegistryEntry
    let isInstalled: Bool
    let isEnabled: Bool
    let isInstalling: Bool
    let errorMessage: String?
    let onInstall: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onUninstall: () -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        entry: RegistryEntry, isInstalled: Bool, isEnabled: Bool, isInstalling: Bool,
        errorMessage: String? = nil,
        onInstall: @escaping () -> Void, onEnabledChange: @escaping (Bool) -> Void,
        onUninstall: @escaping () -> Void, onClose: @escaping () -> Void
    ) {
        self.entry = entry
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.isInstalling = isInstalling
        self.errorMessage = errorMessage
        self.onInstall = onInstall
        self.onEnabledChange = onEnabledChange
        self.onUninstall = onUninstall
        self.onClose = onClose
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        ScrollView {
            VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
                HStack {
                    Text(entry.name).font(JugnuTokens.font(presetId: store.presetId, role: .title2))
                    Spacer()
                    Button("Close", action: onClose)
                }
                Text("Version \(entry.version)")
                    .font(.caption).foregroundStyle(theme.textSecondary)
                Text(entry.description ?? entry.summary)
                    .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                    .foregroundStyle(theme.textPrimary)

                if !entry.commands.isEmpty {
                    Divider()
                    Text("Commands").font(.headline)
                    ForEach(entry.commands, id: \.id) { command in
                        VStack(alignment: .leading) {
                            Text(command.title).font(.subheadline)
                            Text(command.subtitle).font(.caption).foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                Divider()
                AddonActionRow(
                    isInstalled: isInstalled, isEnabled: isEnabled, isInstalling: isInstalling, theme: theme,
                    onInstall: onInstall, onEnabledChange: onEnabledChange, onUninstall: onUninstall
                )

                if let errorMessage {
                    PanelErrorBanner(message: errorMessage)
                }
            }
            .padding(JugnuTokens.Spacing.panelPadding)
        }
        .background(theme.background)
    }
}
