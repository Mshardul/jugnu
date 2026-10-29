import JugnuCore
import SwiftUI

public struct AddonCardView: View {
    let entry: RegistryEntry
    let isInstalled: Bool
    let isEnabled: Bool
    let isInstalling: Bool
    let updateAvailable: Bool
    let errorMessage: String?
    let isFavorite: Bool
    let onInstall: () -> Void
    let onUpdate: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onUninstall: () -> Void
    var onTap: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpen: (() -> Void)?
    var onFavorite: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        entry: RegistryEntry, isInstalled: Bool, isEnabled: Bool, isInstalling: Bool,
        updateAvailable: Bool = false,
        errorMessage: String? = nil,
        isFavorite: Bool = false,
        onInstall: @escaping () -> Void,
        onUpdate: @escaping () -> Void = {},
        onEnabledChange: @escaping (Bool) -> Void,
        onUninstall: @escaping () -> Void,
        onTap: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onFavorite: (() -> Void)? = nil
    ) {
        self.entry = entry
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.isInstalling = isInstalling
        self.updateAvailable = updateAvailable
        self.errorMessage = errorMessage
        self.isFavorite = isFavorite
        self.onInstall = onInstall
        self.onUpdate = onUpdate
        self.onEnabledChange = onEnabledChange
        self.onUninstall = onUninstall
        self.onTap = onTap
        self.onOpenSettings = onOpenSettings
        self.onOpen = onOpen
        self.onFavorite = onFavorite
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        let palette = ShellPalette(theme: theme, colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 9) {
                    icon(palette: palette)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Text(categoryLine)
                            .font(.system(size: 9))
                            .foregroundStyle(palette.muted)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?() }
                    Spacer(minLength: 4)
                    if entry.trust != .community {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.status)
                            .frame(width: 20, height: 20)
                            .background(palette.status.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .accessibilityLabel(entry.trust.label)
                    }
                    Button(action: { onFavorite?() }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isFavorite ? palette.accent : palette.muted)
                            .frame(width: 25, height: 25)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isFavorite ? "Remove \(entry.name) from favorites" :
                        "Add \(entry.name) to favorites")
                }
                Text(entry.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 13)
                HStack(spacing: 7) {
                    metaPill(actionCountLabel, palette: palette)
                    if !entry.permissions.isEmpty {
                        metaPill("Permissions", palette: palette)
                    }
                }
                .padding(.top, 8)
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
            }

            HStack {
                stateLabel(palette: palette)
                Spacer()
                actionControl(palette: palette)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(palette.border).frame(height: 1)
            }

            if let errorMessage {
                PanelErrorBanner(message: errorMessage)
                    .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
    }

    private var categoryLine: String {
        if let subcategory = entry.subcategory, !subcategory.isEmpty {
            return "\(entry.category) · \(subcategory)"
        }
        return entry.category
    }

    private var actionCountLabel: String {
        let count = entry.commands.count
        return count == 1 ? "1 Action" : "\(count) Actions"
    }

    private func icon(palette: ShellPalette) -> some View {
        Image(systemName: catalogSymbol(for: entry.category))
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(palette.sub)
            .frame(width: 34, height: 34)
            .background(palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
    }

    private func metaPill(_ title: String, palette: ShellPalette) -> some View {
        Text(title)
            .font(.system(size: 9))
            .foregroundStyle(palette.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
    }

    private func stateLabel(palette: ShellPalette) -> some View {
        let title: String
        let dot: Color?
        if !isInstalled {
            title = "Not installed"
            dot = nil
        } else if isEnabled {
            title = "Enabled"
            dot = palette.status
        } else {
            title = "Disabled"
            dot = palette.muted
        }
        return HStack(spacing: 6) {
            if let dot {
                Circle().fill(dot).frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(palette.muted)
        }
    }

    @ViewBuilder
    private func actionControl(palette: ShellPalette) -> some View {
        if isInstalling {
            ProgressView()
                .controlSize(.small)
        } else if let action = AddonPrimaryAction.catalogCardAction(
            isInstalled: isInstalled,
            isEnabled: isEnabled,
            updateAvailable: updateAvailable,
            primary: entry.primary
        ) {
            Button(actionTitle(action)) { perform(action) }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(action == .enable ? palette.sub : palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(action == .enable ? palette.soft : palette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(action == .enable ? palette.border : palette.accent.opacity(0.45), lineWidth: 1)
                )
        } else {
            Text("DETAILS ONLY")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.muted)
        }
    }

    private func actionTitle(_ action: CatalogCardAction) -> String {
        switch action {
        case .install: "Install"
        case .update: "Update"
        case .enable: "Enable"
        case .open: "Open"
        }
    }

    private func perform(_ action: CatalogCardAction) {
        switch action {
        case .install: onInstall()
        case .update: onUpdate()
        case .enable: onEnabledChange(true)
        case .open: onOpen?()
        }
    }
}
