import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

struct PrefsView: View {
    @ObservedObject var model: AppModel
    var shellHost: ShellHost
    var onOpenCatalog: () -> Void
    @State private var ids: [String] = []
    @State private var errorText: String?
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Addons")
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title2))
                Text("Enable or uninstall packages under \(model.paths.addonsDir.path)")
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .caption))
                    .foregroundStyle(theme.textSecondary)

                ForEach(ids, id: \.self) { id in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(id).font(.headline)
                            Text(model.config.addons[id]?.enabled == true ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Toggle(
                            "Enabled",
                            isOn: Binding(
                                get: { model.config.addons[id]?.enabled == true },
                                set: { newValue in
                                    if !newValue {
                                        guard DisableWhileTracked.proceed(addonID: id, host: model.processHost) else {
                                            reload()
                                            return
                                        }
                                    }
                                    do {
                                        try model.setEnabled(id: id, enabled: newValue)
                                        reload()
                                    } catch {
                                        errorText = UserFacingError.message(for: error)
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                        Button("Uninstall") {
                            AddonUninstallPresenter.present(
                                id: id, name: model.addonDisplayName(id: id), model: model, shellHost: shellHost
                            ) {
                                reload()
                            }
                        }
                    }
                }

                Button("Install starter addons") {
                    Task {
                        await model.installRecommendedFromRegistry()
                        reload()
                        if let status = model.statusMessage {
                            errorText = status
                        }
                    }
                }

                Button("Browse Catalog…") {
                    onOpenCatalog()
                }

                Divider()

                Text("Theme")
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title2))

                HStack(spacing: 8) {
                    ForEach(JugnuPresets.all, id: \.id) { preset in
                        Button(preset.name) {
                            applyPreset(preset.config)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                themePreview(theme)

                themeEditors(theme)

                Divider()

                Text("Sound")
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title2))
                Toggle("Play a sound when a command finishes", isOn: soundBinding)

                Text("First view")
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title2))
                Picker("Empty search shows", selection: firstViewBinding) {
                    Text("Blank").tag(PaletteFirstView.blank)
                    Text("Recent").tag(PaletteFirstView.recent)
                    Text("Favorites").tag(PaletteFirstView.favorites)
                }
                .pickerStyle(.segmented)

                Text("Catalog: \(model.config.shell.registryURL)")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)

                if let errorText {
                    PanelErrorBanner(message: errorText)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 480, minHeight: 520)
        .background(theme.background)
        .onAppear(perform: reload)
        .onChange(of: model.statusMessage) { _, value in
            if let value { errorText = value }
        }
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { model.config.sound },
            set: { value in
                var config = model.config
                config.sound = value
                try? model.saveConfig(config)
            }
        )
    }

    private var firstViewBinding: Binding<PaletteFirstView> {
        Binding(
            get: { model.config.palette.firstView },
            set: { value in
                var config = model.config
                config.palette.firstView = value
                try? model.saveConfig(config)
            }
        )
    }

    /// Mini launcher-like preview so theme edits are visible while settings replaces the real launcher.
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

    @ViewBuilder
    private func themeEditors(_ theme: JugnuThemeColors) -> some View {
        Group {
            Text("Light").font(.headline)
            colorRow(label: "Accent", keyPath: \.light.accent)
            colorRow(label: "Background", keyPath: \.light.background)
            colorRow(label: "Surface", keyPath: \.light.surface)
            colorRow(label: "Text", keyPath: \.light.textPrimary)
            colorRow(label: "Secondary", keyPath: \.light.textSecondary)
            colorRow(label: "Error", keyPath: \.light.error)
            Text("Dark").font(.headline)
            colorRow(label: "Accent", keyPath: \.dark.accent)
            colorRow(label: "Background", keyPath: \.dark.background)
            colorRow(label: "Surface", keyPath: \.dark.surface)
            colorRow(label: "Text", keyPath: \.dark.textPrimary)
            colorRow(label: "Secondary", keyPath: \.dark.textSecondary)
            colorRow(label: "Error", keyPath: \.dark.error)
        }
        .foregroundStyle(theme.textPrimary)
    }

    private func colorRow(label: String, keyPath: WritableKeyPath<ThemeConfig, String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker(
                label,
                selection: Binding(
                    get: { Color(jugnuHex: model.config.theme[keyPath: keyPath], fallback: .gray) },
                    set: { color in
                        var config = model.config
                        config.theme[keyPath: keyPath] = color.jugnuHex
                        try? model.saveConfig(config)
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
        }
    }

    private func applyPreset(_ preset: ThemeConfig) {
        var config = model.config
        config.theme = preset
        try? model.saveConfig(config)
    }

    private func reload() {
        ids = model.installedAddonIDs()
        model.refreshIndex()
    }
}

private extension Color {
    var jugnuHex: String {
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return "#888888" }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}
