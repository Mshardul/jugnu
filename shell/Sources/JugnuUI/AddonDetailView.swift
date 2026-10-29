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
    let isFavorite: Bool
    let onFavorite: () -> Void

    @State private var tab: AddonDetailTab
    @State private var draftValues: [String: JSONValue] = [:]
    @State private var favoriteOn: Bool
    @State private var actionQuery = ""
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
        onOpen: @escaping () -> Void = {},
        isFavorite: Bool = false,
        onFavorite: @escaping () -> Void = {}
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
        self.isFavorite = isFavorite
        self.onFavorite = onFavorite
        _tab = State(initialValue: initialTab)
        _draftValues = State(initialValue: configValues)
        _favoriteOn = State(initialValue: isFavorite)
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        let palette = ShellPalette(theme: theme, colorScheme: colorScheme)
        HStack(spacing: 0) {
            rail(palette: palette)
                .frame(width: 212)
            VStack(alignment: .leading, spacing: 0) {
                hero(palette: palette)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch tab {
                        case .overview: overviewBody(palette: palette)
                        case .commands: commandsBody(palette: palette)
                        case .widgets: widgetsBody(palette: palette)
                        case .settings: settingsBody(theme: theme, palette: palette)
                        }
                        if let errorMessage {
                            PanelErrorBanner(message: errorMessage)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.frame)
        }
        .background(palette.frame)
        .onChange(of: initialTab) { _, newValue in
            tab = newValue
        }
        .onChange(of: configValues) { _, newValue in
            draftValues = newValue
        }
    }

    private func rail(palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: onClose) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Catalog")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(palette.sub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Text(entry.name.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.muted)
                .tracking(1)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 6)
            sectionButton("Overview", "doc.text", .overview, palette: palette)
            sectionButton("Actions", "play.fill", .commands, palette: palette)
            sectionButton("Widgets", "square.grid.2x2", .widgets, palette: palette)
            sectionButton("Settings", "slider.horizontal.3", .settings, palette: palette)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(palette.soft)
        .overlay(alignment: .trailing) {
            Rectangle().fill(palette.border).frame(width: 1)
        }
    }

    private func sectionButton(_ title: String, _ symbol: String, _ target: AddonDetailTab,
                               palette: ShellPalette) -> some View
    {
        let selected = tab == target
        return Button {
            tab = target
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selected ? palette.accent : palette.sub)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(selected ? palette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func hero(palette: ShellPalette) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: catalogSymbol(for: entry.category))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.sub)
                .frame(width: 40, height: 40)
                .background(palette.soft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(palette.border))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(identityLine)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            primaryHero(palette: palette)
            Button {
                favoriteOn.toggle()
                onFavorite()
            } label: {
                Image(systemName: favoriteOn ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(favoriteOn ? palette.accent : palette.muted)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoriteOn ? "Remove \(entry.name) from favorites" : "Favorite \(entry.name)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var identityLine: String {
        var parts = [entry.category]
        if let subcategory = entry.subcategory, !subcategory.isEmpty {
            parts.append(subcategory)
        }
        parts.append(isInstalled ? "Installed version \(entry.version)" : "Version \(entry.version)")
        if entry.trust != .community {
            parts.append("\(entry.trust.label) Addon")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func primaryHero(palette: ShellPalette) -> some View {
        if isInstalling {
            ProgressView().controlSize(.small)
        } else if let action = AddonPrimaryAction.catalogCardAction(
            isInstalled: isInstalled,
            isEnabled: isEnabled,
            updateAvailable: updateAvailable,
            primary: entry.primary
        ) {
            Button(heroTitle(action)) {
                switch action {
                case .install: onInstall()
                case .update: onUpdate()
                case .enable: onEnabledChange(true)
                case .open: onOpen()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(action == .enable ? palette.sub : palette.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(action == .enable ? palette.soft : palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(action == .enable ? palette.border : palette.accent.opacity(0.45), lineWidth: 1)
            )
        }
    }

    private func heroTitle(_ action: CatalogCardAction) -> String {
        switch action {
        case .install: "Install"
        case .update: "Update"
        case .enable: "Enable"
        case .open: "Open"
        }
    }
}

extension AddonDetailView {
    private func overviewBody(palette: ShellPalette) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(entry.description ?? entry.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
            VStack(alignment: .leading, spacing: 10) {
                fact("Version", entry.version, palette: palette)
                fact("Actions", "\(entry.commands.count)", palette: palette)
                fact("Category", entry.category, palette: palette)
                if updateAvailable {
                    fact("Update", "Available", palette: palette)
                }
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
        }
    }

    private func fact(_ label: String, _ value: String, palette: ShellPalette) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.text)
        }
    }

    private func commandsBody(palette: ShellPalette) -> some View {
        let query = actionQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let commands = entry.commands.filter { command in
            query.isEmpty || command.title.localizedCaseInsensitiveContains(query) || command.subtitle
                .localizedCaseInsensitiveContains(query)
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.muted)
                TextField("Search actions", text: $actionQuery)
                    .textFieldStyle(.plain)
            }
            .font(.system(size: 12))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(palette.border))
            if commands.isEmpty {
                Text(entry.commands.isEmpty ? "This Addon has no actions." : "No actions match.")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(commands, id: \.id) { command in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(command.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(palette.text)
                                Text(command.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.muted)
                            }
                            Spacer()
                            if isInstalled, isEnabled {
                                Button("Run") { onRun(command.id) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(palette.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(palette.border).frame(height: 1)
                        }
                    }
                }
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
            }
        }
    }

    private func widgetsBody(palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isInstalled ? "This Addon has no widgets to place." :
                "Install this Addon before a widget can be placed on Home.")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border))
        }
    }

    private func settingsBody(theme: JugnuThemeColors, palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
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
            if isInstalled {
                Text("On this Mac").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                HStack(spacing: 8) {
                    Button(isEnabled ? "Disable" : "Enable") {
                        onEnabledChange(!isEnabled)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.sub)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(palette.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(palette.border))
                    Button("Uninstall") { onUninstall() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.error)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(theme.error.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
