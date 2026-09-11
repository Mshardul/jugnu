import JugnuCore
import SwiftUI

public struct AddonCardView: View {
    let entry: RegistryEntry
    let isInstalled: Bool
    let isEnabled: Bool
    let isInstalling: Bool
    let updateAvailable: Bool
    let errorMessage: String?
    let onInstall: () -> Void
    let onUpdate: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onUninstall: () -> Void
    var onTap: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpen: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        entry: RegistryEntry, isInstalled: Bool, isEnabled: Bool, isInstalling: Bool,
        updateAvailable: Bool = false,
        errorMessage: String? = nil,
        onInstall: @escaping () -> Void,
        onUpdate: @escaping () -> Void = {},
        onEnabledChange: @escaping (Bool) -> Void,
        onUninstall: @escaping () -> Void,
        onTap: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil
    ) {
        self.entry = entry
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.isInstalling = isInstalling
        self.updateAvailable = updateAvailable
        self.errorMessage = errorMessage
        self.onInstall = onInstall
        self.onUpdate = onUpdate
        self.onEnabledChange = onEnabledChange
        self.onUninstall = onUninstall
        self.onTap = onTap
        self.onOpenSettings = onOpenSettings
        self.onOpen = onOpen
    }

    private var displayTags: [String] {
        entry.tags.isEmpty ? ["untagged"] : entry.tags
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Button(action: { onTap?() }) {
                VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.name)
                            .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
                            .foregroundStyle(theme.textPrimary)
                        if updateAvailable {
                            Text("Update available")
                                .font(.caption2)
                                .foregroundStyle(theme.accent)
                        }
                        Spacer(minLength: 0)
                        if isInstalled {
                            Button {
                                onOpenSettings?()
                            } label: {
                                Text("⚙︎")
                                    .foregroundStyle(theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Settings")
                        }
                    }
                    Text(entry.summary)
                        .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                        .foregroundStyle(theme.textSecondary)
                    if let needs = PermissionsSet.needsLine(entry.permissions) {
                        Text(needs)
                            .font(JugnuTokens.font(presetId: store.presetId, role: .caption2))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Text(entry.category)
                        .font(JugnuTokens.font(presetId: store.presetId, role: .caption2))
                        .foregroundStyle(theme.textSecondary)

                    HStack(spacing: 4) {
                        ForEach(displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(theme.surface)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(theme.textSecondary.opacity(0.3)))
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            AddonActionRow(
                isInstalled: isInstalled,
                isEnabled: isEnabled,
                isInstalling: isInstalling,
                updateAvailable: updateAvailable,
                primary: entry.primary,
                theme: theme,
                onInstall: onInstall,
                onUpdate: onUpdate,
                onEnabledChange: onEnabledChange,
                onUninstall: onUninstall,
                onOpen: { onOpen?() }
            )

            if let errorMessage {
                PanelErrorBanner(message: errorMessage)
            }
        }
        .padding(JugnuTokens.Spacing.panelPadding)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous))
    }
}
