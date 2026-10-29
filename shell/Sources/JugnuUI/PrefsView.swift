import JugnuCore
import SwiftUI

public struct PrefsView: View {
    @Binding var themeConfig: ThemeConfig
    @Binding var sound: Bool
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
    var showsWindowHeader: Bool
    var section: PreferencesSection
    var onSectionChange: (PreferencesSection) -> Void

    @State private var selection: PrefsSelection
    @State private var settingsQuery = ""
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(
        themeConfig: Binding<ThemeConfig>,
        sound: Binding<Bool>,
        keepAppCurrent: Binding<Bool>,
        keepAddonsCurrent: Binding<Bool>,
        shellVersion: String,
        registryURL: String,
        errorText: String? = nil,
        installedAddons: [(id: String, name: String, enabled: Bool)] = [],
        onCheckForUpdates: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onApplyPreset: @escaping (ThemeConfig) -> Void,
        onSelectInstalled: @escaping (String) -> Void = { _ in },
        showsWindowHeader: Bool = true,
        section: PreferencesSection = .appearance,
        onSectionChange: @escaping (PreferencesSection) -> Void = { _ in }
    ) {
        _themeConfig = themeConfig
        _sound = sound
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
        self.showsWindowHeader = showsWindowHeader
        self.section = section
        self.onSectionChange = onSectionChange
        _selection = State(initialValue: Self.prefsSelection(for: section))
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
        VStack(spacing: 0) {
            if showsWindowHeader {
                header(theme: theme)
                Divider()
            }
            HStack(spacing: 0) {
                rail(palette: ShellPalette(theme: theme, colorScheme: colorScheme))
                    .frame(width: 212)
                content(theme: theme, palette: ShellPalette(theme: theme, colorScheme: colorScheme))
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

    private func rail(palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                TextField("Search settings", text: $settingsQuery)
                    .textFieldStyle(.plain)
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.muted)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(palette.frame)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(palette.border))
            .padding(.bottom, 10)
            if paneVisible(.theme) {
                sideLabel("Personal", palette: palette)
                railRow("Appearance", symbol: "paintpalette", selection: .theme, palette: palette)
            }
            if paneVisible(.addonsInstalled) || paneVisible(.addonsUpdates) {
                sideLabel("Addons", palette: palette)
                if paneVisible(.addonsInstalled) {
                    railRow("Installed", symbol: "shippingbox", selection: .addonsInstalled, palette: palette)
                }
                if paneVisible(.addonsUpdates) {
                    railRow(
                        "Updates",
                        symbol: "arrow.triangle.2.circlepath",
                        selection: .addonsUpdates,
                        palette: palette
                    )
                }
            }
            if paneVisible(.general) {
                sideLabel("System", palette: palette)
                railRow("General", symbol: "slider.horizontal.3", selection: .general, palette: palette)
            }
            Spacer()
        }
        .padding(12)
        .background(palette.soft)
        .overlay(alignment: .trailing) { Rectangle().fill(palette.border).frame(width: 1) }
        .onChange(of: settingsQuery) { _, _ in
            if !paneVisible(selection), let next = PrefsSelection.allCases.first(where: paneVisible) {
                choose(next)
            }
        }
    }

    private func paneVisible(_ target: PrefsSelection) -> Bool {
        let query = settingsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if Self.paneKeywords(target)
            .contains(where: { $0.localizedCaseInsensitiveContains(query) || query.localizedCaseInsensitiveContains($0)
            })
        {
            return true
        }
        if target == .addonsInstalled {
            return installedAddons.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return false
    }

    private func sideLabel(_ title: String, palette: ShellPalette) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.muted)
            .tracking(1)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func railRow(
        _ title: String,
        symbol: String,
        selection target: PrefsSelection,
        palette: ShellPalette
    ) -> some View {
        let active = selection == target
        return Button {
            choose(target)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 11.5, weight: active ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(active ? palette.accent : palette.sub)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(active ? palette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func choose(_ target: PrefsSelection) {
        selection = target
        onSectionChange(Self.preferencesSection(for: target))
    }

    private func content(theme: JugnuThemeColors, palette: ShellPalette) -> some View {
        let copy = paneCopy(selection)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(copy.title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .tracking(-0.4)
                        Text(copy.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.muted)
                    }
                    Spacer()
                    Text(copy.trailing)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.muted)
                }
                switch selection {
                case .theme:
                    themePane(theme: theme, palette: palette)
                case .addonsInstalled:
                    installedPane(palette: palette)
                case .addonsUpdates:
                    updatesPane(theme: theme, palette: palette)
                case .general:
                    generalPane(palette: palette)
                }
                if let errorText {
                    PanelErrorBanner(message: errorText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .background(palette.frame)
    }

    private func paneCopy(_ selection: PrefsSelection) -> (title: String, subtitle: String, trailing: String) {
        switch selection {
        case .theme:
            return ("Appearance", "Choose a theme, then tune its light and dark colors.", "Saved")
        case .addonsInstalled:
            let count = installedAddons.count
            let trailing = count == 1 ? "1 installed" : "\(count) installed"
            return (
                "Installed Addons",
                "Open an Addon’s Settings. Installation and lifecycle controls stay in Catalog.",
                trailing
            )
        case .addonsUpdates:
            return ("Updates", "Keep Jugnu and installed Addons current.", "JUGNU \(shellVersion)")
        case .general:
            return ("General", "App-wide behavior that does not belong to an Addon.", "Saved")
        }
    }

    private func themePane(theme: JugnuThemeColors, palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("Theme", palette: palette)
            HStack(spacing: 10) {
                ForEach(JugnuPresets.all, id: \.id) { preset in
                    themeCard(preset, palette: palette)
                }
            }
            sectionLabel("\(selectedPresetName) colors", palette: palette)
            HStack(alignment: .top, spacing: 12) {
                colorEditor("Dark appearance", keys: darkKeys, theme: theme, palette: palette)
                colorEditor("Light appearance", keys: lightKeys, theme: theme, palette: palette)
            }
        }
    }

    private var selectedPresetName: String {
        JugnuPresets.all.first { themeConfig == $0.config }.map { Self.themeCardName(
            $0.id,
            fallback: $0.name
        ) } ?? "Custom"
    }

    private var darkKeys: [(String, WritableKeyPath<ThemeConfig, String>)] {
        [
            ("Background", \.dark.background),
            ("Surface", \.dark.surface),
            ("Accent", \.dark.accent),
            ("Text", \.dark.textPrimary),
            ("Secondary", \.dark.textSecondary),
            ("Subtext", \.dark.subText),
            ("Error", \.dark.error)
        ]
    }

    private var lightKeys: [(String, WritableKeyPath<ThemeConfig, String>)] {
        [
            ("Background", \.light.background),
            ("Surface", \.light.surface),
            ("Accent", \.light.accent),
            ("Text", \.light.textPrimary),
            ("Secondary", \.light.textSecondary),
            ("Subtext", \.light.subText),
            ("Error", \.light.error)
        ]
    }
}

extension PrefsView {
    private func themeCard(
        _ preset: (id: String, name: String, config: ThemeConfig),
        palette: ShellPalette
    ) -> some View {
        let selected = themeConfig == preset.config
        let colors = preset.config.dark
        return Button {
            onApplyPreset(preset.config)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(jugnuHex: colors.accent, fallback: palette.accent)).frame(
                            width: 8,
                            height: 8
                        )
                        RoundedRectangle(cornerRadius: 2).fill(Color(
                            jugnuHex: colors.textSecondary,
                            fallback: palette.muted
                        )).frame(width: 48, height: 4)
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(jugnuHex: colors.textSecondary, fallback: palette.muted).opacity(0.7)).frame(
                            width: 72,
                            height: 4
                        )
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(jugnuHex: colors.textSecondary, fallback: palette.muted).opacity(0.45)).frame(
                            width: 40,
                            height: 4
                        )
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(jugnuHex: colors.background, fallback: palette.frame))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                HStack {
                    Text(Self.themeCardName(preset.id, fallback: preset.name))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(selected ? "Selected" : Self.themeCardKind(preset.id))
                        .font(.system(size: 10))
                }
                .foregroundStyle(selected ? palette.accent : palette.sub)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? palette.accentSoft : palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? palette.accent.opacity(0.45) : palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func colorEditor(
        _ title: String,
        keys: [(String, WritableKeyPath<ThemeConfig, String>)],
        theme: JugnuThemeColors,
        palette: ShellPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)
            ForEach(keys, id: \.0) { label, keyPath in
                colorRow(label: label, keyPath: keyPath, theme: theme, palette: palette)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
    }

    private func installedPane(palette: ShellPalette) -> some View {
        let rows = filteredInstalled
        return VStack(alignment: .leading, spacing: 12) {
            Text(
                "Enable, disable, update, and uninstall Addons in Catalog. This page links only to settings that already exist."
            )
            .font(.system(size: 11))
            .foregroundStyle(palette.sub)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if rows.isEmpty {
                Text(installedAddons.isEmpty ? "No Addons installed yet." : "No installed Addons match this search.")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.id) { row in
                        Button {
                            onSelectInstalled(row.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(palette.sub)
                                    .frame(width: 34, height: 34)
                                    .background(palette.soft)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    Text(row.enabled ? "Enabled" : "Disabled")
                                        .font(.system(size: 11))
                                        .foregroundStyle(palette.muted)
                                }
                                Spacer()
                                Text("Open Settings")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(palette.accent)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(palette.muted)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) { Rectangle().fill(palette.border).frame(height: 1) }
                    }
                }
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
            }
        }
    }

    private var filteredInstalled: [(id: String, name: String, enabled: Bool)] {
        let query = settingsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return installedAddons }
        return installedAddons.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func updatesPane(theme: JugnuThemeColors, palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                statusCard(
                    symbol: "checkmark",
                    title: "Jugnu \(shellVersion)",
                    detail: "Checked from Preferences",
                    tint: palette.status,
                    palette: palette
                )
            }
            sectionLabel("Automatic updates", palette: palette)
            settingsCard(palette: palette) {
                settingRow(
                    title: "Keep Jugnu current",
                    detail: "Download verified Jugnu updates automatically.",
                    palette: palette
                ) {
                    shellToggle($keepAppCurrent, label: "Keep Jugnu current", palette: palette)
                }
                settingRow(
                    title: "Keep Addons current",
                    detail: "Update installed Addons when permissions do not grow.",
                    palette: palette
                ) {
                    shellToggle($keepAddonsCurrent, label: "Keep Addons current", palette: palette)
                }
            }
            sectionLabel("Manual check", palette: palette)
            settingsCard(palette: palette) {
                settingRow(
                    title: "Check for Updates",
                    detail: "Check Jugnu and the Addon registry now.",
                    palette: palette
                ) {
                    Button("Check now", action: onCheckForUpdates)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Registry")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text(registryURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(palette.muted)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(theme.error)
            }
        }
    }

    private func generalPane(palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Sound", palette: palette)
            settingsCard(palette: palette) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.sub)
                        .frame(width: 34, height: 34)
                        .background(palette.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interface sounds")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Text("Play subtle feedback for completed actions and errors.")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.muted)
                    }
                    Spacer()
                    shellToggle($sound, label: "Interface sounds", palette: palette)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private func sectionLabel(_ title: String, palette: ShellPalette) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.text)
    }

    private func statusCard(symbol: String, title: String, detail: String, tint: Color,
                            palette: ShellPalette) -> some View
    {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                Text(detail).font(.system(size: 11)).foregroundStyle(palette.muted)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
    }

    private func settingsCard(palette: ShellPalette, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
    }

    private func settingRow(
        title: String,
        detail: String,
        palette: ShellPalette,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                Text(detail).font(.system(size: 11)).foregroundStyle(palette.muted)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.border).frame(height: 1) }
    }

    private func shellToggle(_ isOn: Binding<Bool>, label: String, palette: ShellPalette) -> some View {
        Toggle(label, isOn: isOn)
            .labelsHidden()
            .toggleStyle(ShellToggleStyle(palette: palette))
            .accessibilityLabel(label)
    }

    private func colorRow(
        label: String,
        keyPath: WritableKeyPath<ThemeConfig, String>,
        theme _: JugnuThemeColors,
        palette: ShellPalette
    ) -> some View {
        let hex = themeConfig[keyPath: keyPath]
        return HStack(spacing: 10) {
            ColorPicker(
                label,
                selection: Binding(
                    get: { Color(jugnuHex: hex, fallback: .gray) },
                    set: { color in
                        themeConfig[keyPath: keyPath] = color.jugnuHex
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(palette.sub)
            Spacer()
            Text(hex.uppercased())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private static func prefsSelection(for section: PreferencesSection) -> PrefsSelection {
        switch section {
        case .appearance: .theme
        case .installed: .addonsInstalled
        case .updates: .addonsUpdates
        case .general: .general
        }
    }

    private static func preferencesSection(for selection: PrefsSelection) -> PreferencesSection {
        switch selection {
        case .theme: .appearance
        case .addonsInstalled: .installed
        case .addonsUpdates: .updates
        case .general: .general
        }
    }

    private static func themeCardName(_ id: String, fallback: String) -> String {
        id == "terminalPhosphor" ? "Phosphor" : fallback
    }

    private static func themeCardKind(_ id: String) -> String {
        id == "roseQuartz" ? "Light" : "Dark"
    }

    private static func paneKeywords(_ selection: PrefsSelection) -> [String] {
        switch selection {
        case .theme: ["appearance", "theme", "color", "firefly", "phosphor", "rose", "accent", "background"]
        case .addonsInstalled: ["installed", "addon", "settings"]
        case .addonsUpdates: ["updates", "registry", "version", "current"]
        case .general: ["general", "sound", "interface"]
        }
    }
}

private struct ShellToggleStyle: ToggleStyle {
    var palette: ShellPalette

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? palette.accent : palette.soft)
                    .frame(width: 36, height: 20)
                    .overlay(Capsule().strokeBorder(palette.border, lineWidth: 1))
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}
