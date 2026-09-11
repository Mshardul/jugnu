import JugnuCore
import SwiftUI

public struct PrefsView: View {
    @Binding var themeConfig: ThemeConfig
    @Binding var sound: Bool
    @Binding var firstView: PaletteFirstView
    @Binding var keepAppCurrent: Bool
    @Binding var keepAddonsCurrent: Bool
    var shellVersion: String
    var registryURL: String
    var errorText: String?
    var installedAddons: [(id: String, name: String, enabled: Bool)]
    var onCheckForUpdates: () -> Void
    var onClose: () -> Void
    var onApplyPreset: (ThemeConfig) -> Void
    var onSelectInstalled: (String) -> Void

    @State private var selection: PrefsSelection = .default
    @State private var addonsExpanded = true
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(
        themeConfig: Binding<ThemeConfig>,
        sound: Binding<Bool>,
        firstView: Binding<PaletteFirstView>,
        keepAppCurrent: Binding<Bool>,
        keepAddonsCurrent: Binding<Bool>,
        shellVersion: String,
        registryURL: String,
        errorText: String? = nil,
        installedAddons: [(id: String, name: String, enabled: Bool)] = [],
        onCheckForUpdates: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onApplyPreset: @escaping (ThemeConfig) -> Void,
        onSelectInstalled: @escaping (String) -> Void = { _ in }
    ) {
        _themeConfig = themeConfig
        _sound = sound
        _firstView = firstView
        _keepAppCurrent = keepAppCurrent
        _keepAddonsCurrent = keepAddonsCurrent
        self.shellVersion = shellVersion
        self.registryURL = registryURL
        self.errorText = errorText
        self.installedAddons = installedAddons
        self.onCheckForUpdates = onCheckForUpdates
        self.onClose = onClose
        self.onApplyPreset = onApplyPreset
        self.onSelectInstalled = onSelectInstalled
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
        VStack(spacing: 0) {
            header(theme: theme)
            Divider()
            HStack(spacing: 0) {
                rail(theme: theme)
                    .frame(width: 160)
                Divider()
                content(theme: theme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(theme.background)
        .frame(minWidth: 720, minHeight: 480)
    }

    private func header(theme: JugnuThemeColors) -> some View {
        HStack {
            Text("Preferences")
                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title2))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button(action: onClose) {
                Text("✕")
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func rail(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            railRow("Theme", selection: .theme, theme: theme)
            Button {
                addonsExpanded.toggle()
            } label: {
                HStack {
                    Text("Addons")
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(addonsExpanded ? "▾" : "▸")
                        .foregroundStyle(theme.textSecondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if addonsExpanded {
                railRow("Installed", selection: .addonsInstalled, theme: theme, indented: true)
                railRow("Updates", selection: .addonsUpdates, theme: theme, indented: true)
            }
            railRow("General", selection: .general, theme: theme)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(theme.surface)
    }

    private func railRow(
        _ title: String,
        selection target: PrefsSelection,
        theme: JugnuThemeColors,
        indented: Bool = false
    ) -> some View {
        let active = selection == target
        return Button {
            selection = target
            if target == .addonsUpdates || target == .addonsInstalled {
                addonsExpanded = true
            }
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(active ? theme.accent : Color.clear)
                    .frame(width: 3)
                Text(title)
                    .foregroundStyle(active ? theme.textPrimary : theme.subText)
                    .padding(.leading, indented ? 18 : 10)
                    .padding(.vertical, 8)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func content(theme: JugnuThemeColors) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(PrefsPaneTitle.title(for: selection))
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title2))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.bottom, 8)

                switch selection {
                case .theme:
                    themePane(theme: theme)
                case .addonsInstalled:
                    installedPane(theme: theme)
                case .addonsUpdates:
                    updatesPane(theme: theme)
                case .general:
                    generalPane(theme: theme)
                }

                if let errorText {
                    PanelErrorBanner(message: errorText)
                        .padding(.top, 12)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func themePane(theme: JugnuThemeColors) -> some View {
        HStack(spacing: 8) {
            ForEach(JugnuPresets.all, id: \.id) { preset in
                Button(preset.name) {
                    onApplyPreset(preset.config)
                }
                .buttonStyle(.bordered)
            }
        }
        themePreview(theme)
            .padding(.vertical, 8)
        Text("Light")
            .font(.headline)
            .foregroundStyle(theme.textPrimary)
        colorRow(label: "Accent", keyPath: \.light.accent, theme: theme)
        colorRow(label: "Background", keyPath: \.light.background, theme: theme)
        colorRow(label: "Surface", keyPath: \.light.surface, theme: theme)
        colorRow(label: "Text", keyPath: \.light.textPrimary, theme: theme)
        colorRow(label: "Secondary", keyPath: \.light.textSecondary, theme: theme)
        colorRow(label: "Subtext", keyPath: \.light.subText, theme: theme)
        colorRow(label: "Error", keyPath: \.light.error, theme: theme)
        Text("Dark")
            .font(.headline)
            .foregroundStyle(theme.textPrimary)
            .padding(.top, 8)
        colorRow(label: "Accent", keyPath: \.dark.accent, theme: theme)
        colorRow(label: "Background", keyPath: \.dark.background, theme: theme)
        colorRow(label: "Surface", keyPath: \.dark.surface, theme: theme)
        colorRow(label: "Text", keyPath: \.dark.textPrimary, theme: theme)
        colorRow(label: "Secondary", keyPath: \.dark.textSecondary, theme: theme)
        colorRow(label: "Subtext", keyPath: \.dark.subText, theme: theme)
        colorRow(label: "Error", keyPath: \.dark.error, theme: theme)
    }

    private func installedPane(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if installedAddons.isEmpty {
                Text("No addons installed yet. Use Browse Addons to install.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(installedAddons, id: \.id) { row in
                    Button {
                        onSelectInstalled(row.id)
                    } label: {
                        PreferenceRow(
                            title: row.name,
                            description: row.enabled ? "Enabled" : "Disabled",
                            titleColor: theme.textPrimary,
                            descriptionColor: theme.textSecondary
                        ) {
                            Text("›")
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func updatesPane(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Jugnu \(shellVersion)")
                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .caption))
                .foregroundStyle(theme.textSecondary)
            PreferenceRow(
                title: "Keep Jugnu current",
                titleColor: theme.textPrimary,
                descriptionColor: theme.textSecondary
            ) {
                Toggle("", isOn: $keepAppCurrent).labelsHidden()
            }
            Divider()
            PreferenceRow(
                title: "Keep addons current",
                titleColor: theme.textPrimary,
                descriptionColor: theme.textSecondary
            ) {
                Toggle("", isOn: $keepAddonsCurrent).labelsHidden()
            }
            Divider()
            Button("Check for Updates", action: onCheckForUpdates)
                .padding(.top, 8)
            Text("Catalog: \(registryURL)")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
                .padding(.top, 4)
        }
    }

    private func generalPane(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            PreferenceRow(
                title: "Play a sound when a command finishes",
                titleColor: theme.textPrimary,
                descriptionColor: theme.textSecondary
            ) {
                Toggle("", isOn: $sound).labelsHidden()
            }
            Divider()
            Text("Empty search shows")
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 8)
            Picker("", selection: $firstView) {
                Text("Blank").tag(PaletteFirstView.blank)
                Text("Recent").tag(PaletteFirstView.recent)
                Text("Favorites").tag(PaletteFirstView.favorites)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func themePreview(_ theme: JugnuThemeColors) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.background)
                .frame(width: 120, height: 44)
                .overlay(
                    Text("Search…")
                        .font(JugnuTokens.font(presetId: themeStore.presetId, role: .caption))
                        .foregroundStyle(theme.textSecondary)
                )
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.surface)
                .frame(width: 120, height: 44)
                .overlay(
                    Text("Aa")
                        .font(JugnuTokens.font(presetId: themeStore.presetId, role: .headline))
                        .foregroundStyle(theme.textPrimary)
                )
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.accent)
                .frame(width: 28, height: 28)
        }
        .padding(8)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.2))
        )
    }

    private func colorRow(
        label: String,
        keyPath: WritableKeyPath<ThemeConfig, String>,
        theme: JugnuThemeColors
    ) -> some View {
        PreferenceRow(title: label, titleColor: theme.textPrimary, descriptionColor: theme.textSecondary) {
            ColorPicker(
                label,
                selection: Binding(
                    get: { Color(jugnuHex: themeConfig[keyPath: keyPath], fallback: .gray) },
                    set: { color in
                        themeConfig[keyPath: keyPath] = color.jugnuHex
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
        }
    }
}
