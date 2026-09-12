import JugnuCore
import SwiftUI

public struct AddonDetailView: View {
    let entry: RegistryEntry
    let isInstalled: Bool
    let isEnabled: Bool
    let isInstalling: Bool
    let updateAvailable: Bool
    let errorMessage: String?
    var initialTab: AddonDetailTab = .overview
    // TCC grants only
    var permissionGrants: [AddonPermission: Bool] = [:]
    var configSchema: [AddonConfigField] = []
    var configValues: [String: JSONValue] = [:]
    var configError: String?
    let onInstall: () -> Void
    let onUpdate: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onUninstall: () -> Void
    let onRun: (String) -> Void
    let onConfigChange: (String, JSONValue) -> Void
    let onOpenConfig: () -> Void
    let onResetConfig: () -> Void
    let onClose: () -> Void
    let onOpen: () -> Void

    @State private var tab: AddonDetailTab
    @State private var draftValues: [String: JSONValue] = [:]
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        entry: RegistryEntry,
        isInstalled: Bool,
        isEnabled: Bool,
        isInstalling: Bool,
        updateAvailable: Bool = false,
        errorMessage: String? = nil,
        initialTab: AddonDetailTab = .overview,
        permissionGrants: [AddonPermission: Bool] = [:],
        configSchema: [AddonConfigField] = [],
        configValues: [String: JSONValue] = [:],
        configError: String? = nil,
        onInstall: @escaping () -> Void,
        onUpdate: @escaping () -> Void = {},
        onEnabledChange: @escaping (Bool) -> Void,
        onUninstall: @escaping () -> Void,
        onRun: @escaping (String) -> Void = { _ in },
        onConfigChange: @escaping (String, JSONValue) -> Void = { _, _ in },
        onOpenConfig: @escaping () -> Void = {},
        onResetConfig: @escaping () -> Void = {},
        onClose: @escaping () -> Void,
        onOpen: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.isInstalling = isInstalling
        self.updateAvailable = updateAvailable
        self.errorMessage = errorMessage
        self.initialTab = initialTab
        self.permissionGrants = permissionGrants
        self.configSchema = configSchema
        self.configValues = configValues
        self.configError = configError
        self.onInstall = onInstall
        self.onUpdate = onUpdate
        self.onEnabledChange = onEnabledChange
        self.onUninstall = onUninstall
        self.onRun = onRun
        self.onConfigChange = onConfigChange
        self.onOpenConfig = onOpenConfig
        self.onResetConfig = onResetConfig
        self.onClose = onClose
        self.onOpen = onOpen
        _tab = State(initialValue: initialTab)
        _draftValues = State(initialValue: configValues)
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        VStack(alignment: .leading, spacing: 0) {
            header(theme: theme)
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
                onOpen: onOpen
            )
            .padding(.horizontal, JugnuTokens.Spacing.panelPadding)
            .padding(.bottom, 8)

            tabStrip(theme: theme)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
                    switch tab {
                    case .overview: overviewBody(theme: theme)
                    case .commands: commandsBody(theme: theme)
                    case .settings: settingsBody(theme: theme)
                    }
                    if let errorMessage {
                        PanelErrorBanner(message: errorMessage)
                    }
                }
                .padding(JugnuTokens.Spacing.panelPadding)
            }
        }
        .background(theme.background)
        .onChange(of: initialTab) { _, newValue in
            tab = newValue
        }
        .onChange(of: configValues) { _, newValue in
            draftValues = newValue
        }
    }

    private func header(theme: JugnuThemeColors) -> some View {
        HStack {
            Text(entry.name)
                .font(JugnuTokens.font(presetId: store.presetId, role: .title2))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button(action: onClose) {
                Text("✕").foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(JugnuTokens.Spacing.panelPadding)
    }

    private func tabStrip(theme: JugnuThemeColors) -> some View {
        HStack(spacing: 16) {
            tabButton("Overview", .overview, theme: theme)
            tabButton("Commands", .commands, theme: theme)
            tabButton("Settings", .settings, theme: theme)
            Spacer()
        }
        .padding(.horizontal, JugnuTokens.Spacing.panelPadding)
        .padding(.bottom, 8)
    }

    private func tabButton(_ title: String, _ target: AddonDetailTab, theme: JugnuThemeColors) -> some View {
        Button {
            tab = target
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                    .foregroundStyle(tab == target ? theme.textPrimary : theme.subText)
                Rectangle()
                    .fill(tab == target ? theme.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func overviewBody(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            HStack(spacing: 8) {
                Text("Version \(entry.version)")
                    .font(.caption).foregroundStyle(theme.textSecondary)
                Text("·").foregroundStyle(theme.textSecondary)
                Text("\(entry.commands.count) commands")
                    .font(.caption).foregroundStyle(theme.textSecondary)
                if updateAvailable {
                    Text("Update available")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                }
            }
            Text(entry.description ?? entry.summary)
                .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func commandsBody(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.commands.isEmpty {
                Text("This addon has no commands.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(entry.commands, id: \.id) { command in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(command.title).font(.subheadline)
                                .foregroundStyle(theme.textPrimary)
                            Text(command.subtitle).font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        if isInstalled, isEnabled {
                            Button("Run") { onRun(command.id) }
                                .buttonStyle(.bordered)
                        }
                    }
                    Divider()
                }
            }
        }
    }

    private func settingsBody(theme: JugnuThemeColors) -> some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Text("Permissions").font(.headline).foregroundStyle(theme.textPrimary)
            if entry.permissions.isEmpty {
                Text("This addon does not need special permissions.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(PermissionsSet.sort(entry.permissions), id: \.rawValue) { permission in
                    HStack {
                        Text("\(permission.displayTitle) — \(permission.reason)")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        if permission.isTCC, let granted = permissionGrants[permission] {
                            Text(granted ? "Granted" : "Needed")
                                .font(.caption2)
                                .foregroundStyle(granted ? theme.textSecondary : theme.error)
                        }
                    }
                }
            }
            Divider()
            Text("Settings").font(.headline).foregroundStyle(theme.textPrimary)
            if let configError {
                Text(configError)
                    .font(.caption)
                    .foregroundStyle(theme.error)
                HStack {
                    Button("Open") { onOpenConfig() }
                    Button("Reset") { onResetConfig() }
                }
            } else if configSchema.isEmpty {
                Text("No settings for this addon.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(configSchema, id: \.key) { field in
                    configRow(field: field, theme: theme)
                }
            }
        }
    }

    @ViewBuilder
    private func configRow(field: AddonConfigField, theme: JugnuThemeColors) -> some View {
        let title = field.key.replacingOccurrences(of: "_", with: " ").capitalized
        PreferenceRow(title: title, titleColor: theme.textPrimary, descriptionColor: theme.textSecondary) {
            switch field.type {
            case .bool:
                Toggle(
                    "",
                    isOn: Binding(
                        get: {
                            if case let .bool(b) = draftValues[field.key] ?? field.default {
                                return b
                            }
                            return false
                        },
                        set: { newValue in
                            draftValues[field.key] = .bool(newValue)
                            onConfigChange(field.key, .bool(newValue))
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            case .enum:
                Picker(
                    "",
                    selection: Binding(
                        get: {
                            if case let .string(s) = draftValues[field.key] ?? field.default {
                                return s
                            }
                            return field.values?.first ?? ""
                        },
                        set: { newValue in
                            draftValues[field.key] = .string(newValue)
                            onConfigChange(field.key, .string(newValue))
                        }
                    )
                ) {
                    ForEach(field.values ?? [], id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)
            case .int:
                TextField(
                    "0",
                    text: Binding(
                        get: {
                            if case let .number(n) = draftValues[field.key] ?? field.default {
                                return String(Int(n))
                            }
                            return "0"
                        },
                        set: { text in
                            guard let parsed = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                            let value = JSONValue.number(Double(parsed))
                            draftValues[field.key] = value
                            onConfigChange(field.key, value)
                        }
                    )
                )
                .frame(width: 72)
                .multilineTextAlignment(.trailing)
            case .string:
                TextField(
                    "",
                    text: Binding(
                        get: {
                            if case let .string(s) = draftValues[field.key] ?? field.default {
                                return s
                            }
                            return ""
                        },
                        set: { text in
                            draftValues[field.key] = .string(text)
                            onConfigChange(field.key, .string(text))
                        }
                    )
                )
                .frame(maxWidth: 180)
                .multilineTextAlignment(.trailing)
            }
        }
    }
}
