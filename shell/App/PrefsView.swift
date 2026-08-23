import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

struct PrefsView: View {
    @ObservedObject var model: AppModel
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
                            AddonUninstallPresenter.present(id: id, name: id, model: model) {
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
                    model.openBrowseCatalog()
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
