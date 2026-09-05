import Foundation

public struct JugnuTheme: Codable, Equatable, Sendable {
    public var accent: String
    public var background: String
    public var surface: String
    public var textPrimary: String
    public var textSecondary: String
    public var subText: String
    public var error: String

    public init(
        accent: String,
        background: String,
        surface: String,
        textPrimary: String,
        textSecondary: String,
        subText: String,
        error: String
    ) {
        self.accent = accent
        self.background = background
        self.surface = surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.subText = subText
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case accent
        case background
        case surface
        case textPrimary = "text_primary"
        case textSecondary = "text_secondary"
        case subText = "sub_text"
        case error
    }

    public func sanitized(against defaults: JugnuTheme) -> JugnuTheme {
        func hex(_ value: String, _ fallback: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let ok = trimmed.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
            return ok ? trimmed : fallback
        }
        return JugnuTheme(
            accent: hex(accent, defaults.accent),
            background: hex(background, defaults.background),
            surface: hex(surface, defaults.surface),
            textPrimary: hex(textPrimary, defaults.textPrimary),
            textSecondary: hex(textSecondary, defaults.textSecondary),
            subText: hex(subText, defaults.subText),
            error: hex(error, defaults.error)
        )
    }
}

public struct ThemeConfig: Codable, Equatable, Sendable {
    public var light: JugnuTheme
    public var dark: JugnuTheme

    public init(light: JugnuTheme, dark: JugnuTheme) {
        self.light = light
        self.dark = dark
    }

    public static let firefly = ThemeConfig(
        light: JugnuTheme(
            accent: "#C97A12",
            background: "#F7F3EA",
            surface: "#FFFDF8",
            textPrimary: "#2A2417",
            textSecondary: "#756E5C",
            subText: "#5B5647",
            error: "#E5484D"
        ),
        dark: JugnuTheme(
            accent: "#F5A623",
            background: "#16130E",
            surface: "#1F1B13",
            textPrimary: "#EDE6D9",
            textSecondary: "#8C8577",
            subText: "#B8AF9E",
            error: "#E5484D"
        )
    )

    public static let terminalPhosphor = ThemeConfig(
        light: JugnuTheme(
            accent: "#1C8A3F",
            background: "#EEF3EC",
            surface: "#F7FAF6",
            textPrimary: "#12291A",
            textSecondary: "#4F6D57",
            subText: "#385E43",
            error: "#E5484D"
        ),
        dark: JugnuTheme(
            accent: "#39FF6A",
            background: "#020402",
            surface: "#020402",
            textPrimary: "#C9FFD4",
            textSecondary: "#3A8A4A",
            subText: "#6FAF7C",
            error: "#E5484D"
        )
    )

    public static let roseQuartz = ThemeConfig(
        light: JugnuTheme(
            accent: "#D13D82",
            background: "#FDF0F6",
            surface: "#FFFAFD",
            textPrimary: "#4A1936",
            textSecondary: "#93677F",
            subText: "#6F4A5E",
            error: "#E5484D"
        ),
        dark: JugnuTheme(
            accent: "#F0559B",
            background: "#210F1A",
            surface: "#2E1524",
            textPrimary: "#FBE6F1",
            textSecondary: "#B98AA7",
            subText: "#D2A9BF",
            error: "#E5484D"
        )
    )
}

public enum PaletteFirstView: String, Codable, Sendable {
    case blank
    case recent
    case favorites
}

public struct PaletteConfig: Codable, Equatable, Sendable {
    public var firstView: PaletteFirstView

    public init(firstView: PaletteFirstView = .blank) {
        self.firstView = firstView
    }

    enum CodingKeys: String, CodingKey {
        case firstView = "first_view"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstView = try container.decodeIfPresent(PaletteFirstView.self, forKey: .firstView) ?? .blank
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(firstView, forKey: .firstView)
    }
}

public struct JugnuConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var shell: ShellConfig
    public var addons: [String: AddonConfig]
    public var ui: [String: String]
    public var theme: ThemeConfig
    public var sound: Bool
    public var palette: PaletteConfig

    public init(
        version: Int = 1,
        shell: ShellConfig = ShellConfig(),
        addons: [String: AddonConfig] = [:],
        ui: [String: String] = [:],
        theme: ThemeConfig = .firefly,
        sound: Bool = true,
        palette: PaletteConfig = PaletteConfig()
    ) {
        self.version = version
        self.shell = shell
        self.addons = addons
        self.ui = ui
        self.theme = theme
        self.sound = sound
        self.palette = palette
    }

    enum CodingKeys: String, CodingKey {
        case version
        case shell
        case addons
        case ui
        case theme
        case sound
        case palette
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        shell = try container.decodeIfPresent(ShellConfig.self, forKey: .shell) ?? ShellConfig()
        addons = try container.decodeIfPresent([String: AddonConfig].self, forKey: .addons) ?? [:]
        ui = try container.decodeIfPresent([String: String].self, forKey: .ui) ?? [:]
        theme = try container.decodeIfPresent(ThemeConfig.self, forKey: .theme) ?? .firefly
        sound = try container.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        palette = try container.decodeIfPresent(PaletteConfig.self, forKey: .palette) ?? PaletteConfig()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(shell, forKey: .shell)
        try container.encode(addons, forKey: .addons)
        try container.encode(ui, forKey: .ui)
        try container.encode(theme, forKey: .theme)
        try container.encode(sound, forKey: .sound)
        try container.encode(palette, forKey: .palette)
    }
}

public struct ShellConfig: Codable, Equatable, Sendable {
    public var hotkey: String
    /// Catalog JSON URL (GitHub raw or release-pinned).
    public var registryURL: String
    /// Shell-native palette commands to hide: "browse-addons", "preferences".
    /// These are mandatory chrome, not addons, so there is no My Addons toggle for them.
    public var hiddenShellCommands: Set<String>

    public static let defaultRegistryURL =
        "https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/addons.json"

    public static func helpersCatalogURL(from registryURL: String) -> String {
        if let range = registryURL.range(of: "addons.json", options: [.backwards]),
           range.upperBound == registryURL.endIndex
        {
            return registryURL.replacingCharacters(in: range, with: "helpers.json")
        }
        return registryURL
    }

    public static let recommendedAddonIDs = [
        "jugnu.mic-mute", "jugnu.focus-toggle", "jugnu.paste-plain", "jugnu.floating-note", "jugnu.ports"
    ]

    public init(
        hotkey: String = "option+space",
        registryURL: String = ShellConfig.defaultRegistryURL,
        hiddenShellCommands: Set<String> = []
    ) {
        self.hotkey = hotkey
        self.registryURL = registryURL
        self.hiddenShellCommands = hiddenShellCommands
    }

    enum CodingKeys: String, CodingKey {
        case hotkey
        case registryURL = "registry_url"
        case hiddenShellCommands = "hidden_shell_commands"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? "option+space"
        registryURL = try c.decodeIfPresent(String.self, forKey: .registryURL) ?? Self.defaultRegistryURL
        hiddenShellCommands = try c.decodeIfPresent(Set<String>.self, forKey: .hiddenShellCommands) ?? []
    }
}

public struct AddonConfig: Codable, Equatable, Sendable {
    public var enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

public struct CommandUISpec: Codable, Equatable, Sendable {
    public var pattern: UIPattern

    public init(pattern: UIPattern) {
        self.pattern = pattern
    }
}

public struct CommandDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var keywords: [String]
    public var ui: CommandUISpec?
    public var view: ViewType?
    public var lifecycle: LifecycleClass?
    public var onReinvoke: OnReinvoke?
    public var timeout: TimeInterval?
    public var daemon: DaemonBlock?

    public init(
        id: String,
        title: String,
        subtitle: String,
        keywords: [String] = [],
        ui: CommandUISpec? = nil,
        view: ViewType? = nil,
        lifecycle: LifecycleClass? = nil,
        onReinvoke: OnReinvoke? = nil,
        timeout: TimeInterval? = nil,
        daemon: DaemonBlock? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.ui = ui
        self.view = view
        self.lifecycle = lifecycle
        self.onReinvoke = onReinvoke
        self.timeout = timeout
        self.daemon = daemon
    }

    public var defaultUIPattern: UIPattern? {
        ui?.pattern
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, keywords, ui, view, lifecycle, timeout, daemon
        case onReinvoke = "on_reinvoke"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        ui = try c.decodeIfPresent(CommandUISpec.self, forKey: .ui)
        if let raw = try c.decodeIfPresent(String.self, forKey: .view) {
            guard let parsed = ViewType(rawValue: raw) else {
                throw ManifestLoaderError.unknownViewType(raw)
            }
            view = parsed
        } else {
            view = nil
        }
        lifecycle = try LifecycleClass.decodeManifestValue(c.decodeIfPresent(String.self, forKey: .lifecycle))
        onReinvoke = try c.decodeIfPresent(OnReinvoke.self, forKey: .onReinvoke)
        timeout = try c.decodeIfPresent(TimeInterval.self, forKey: .timeout)
        daemon = try c.decodeIfPresent(DaemonBlock.self, forKey: .daemon)
    }
}

public struct Entrypoint: Codable, Equatable, Sendable {
    public var kind: String
    public var path: String

    public init(kind: String, path: String) {
        self.kind = kind
        self.path = path
    }
}

public struct CleanupSpec: Codable, Equatable, Sendable {
    public var paths: [String]
    public var launchd: [String]

    public init(paths: [String] = [], launchd: [String] = []) {
        self.paths = paths
        self.launchd = launchd
    }
}

public struct HelperRef: Codable, Equatable, Sendable {
    public var id: String
    public var version: String

    public init(id: String, version: String) {
        self.id = id
        self.version = version
    }

    public var environmentVariable: String {
        "JUGNU_HELPER_" + id.replacingOccurrences(of: "-", with: "_").uppercased()
    }
}

/// Catalog-addon dependency (exact SemVer). Distinct from `helpers:`.
public struct AddonDependency: Codable, Equatable, Sendable {
    public var id: String
    public var version: String

    public init(id: String, version: String) {
        self.id = id
        self.version = version
    }
}

public struct HelperManifest: Codable, Equatable, Sendable {
    public var id: String
    public var version: String

    public init(id: String, version: String) {
        self.id = id
        self.version = version
    }
}

public struct AddonManifest: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var api: Int
    public var commands: [CommandDescriptor]
    public var entrypoint: Entrypoint
    public var cleanup: CleanupSpec
    public var viewTypes: [ViewType]
    public var helpers: [HelperRef]
    public var dependencies: [AddonDependency]
    public var lifecycle: LifecycleClass?
    public var minShellVersion: String?

    public var allowedViewTypes: [ViewType] {
        viewTypes.isEmpty ? ViewType.shellDefaults : viewTypes
    }

    public func effectiveLifecycle(commandId: String) -> LifecycleClass {
        let command = commands.first { $0.id == commandId }
        return command?.lifecycle ?? lifecycle ?? .oneshot
    }

    public func effectiveOnReinvoke(commandId: String) -> OnReinvoke {
        commands.first { $0.id == commandId }?.onReinvoke ?? .reuse
    }

    public func effectiveCleanupLaunchd() -> [String] {
        var labels = Set(cleanup.launchd)
        for command in commands where effectiveLifecycle(commandId: command.id) == .daemon {
            labels.insert(FirstPartyDaemons.launchdLabel(addonID: id, commandID: command.id))
        }
        return labels.sorted()
    }

    public init(
        id: String,
        name: String,
        version: String,
        api: Int,
        commands: [CommandDescriptor],
        entrypoint: Entrypoint,
        cleanup: CleanupSpec = CleanupSpec(),
        viewTypes: [ViewType] = [],
        helpers: [HelperRef] = [],
        dependencies: [AddonDependency] = [],
        lifecycle: LifecycleClass? = nil,
        minShellVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.api = api
        self.commands = commands
        self.entrypoint = entrypoint
        self.cleanup = cleanup
        self.viewTypes = viewTypes
        self.helpers = helpers
        self.dependencies = dependencies
        self.lifecycle = lifecycle
        self.minShellVersion = minShellVersion
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, api, commands, entrypoint, cleanup, helpers, dependencies, lifecycle
        case viewTypes = "view_types"
        case minShellVersion
        case minShellVersionSnake = "min_shell_version"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        version = try c.decode(String.self, forKey: .version)
        api = try c.decode(Int.self, forKey: .api)
        commands = try c.decode([CommandDescriptor].self, forKey: .commands)
        entrypoint = try c.decode(Entrypoint.self, forKey: .entrypoint)
        cleanup = try c.decodeIfPresent(CleanupSpec.self, forKey: .cleanup) ?? CleanupSpec()
        helpers = try c.decodeIfPresent([HelperRef].self, forKey: .helpers) ?? []
        dependencies = try c.decodeIfPresent([AddonDependency].self, forKey: .dependencies) ?? []
        lifecycle = try LifecycleClass.decodeManifestValue(c.decodeIfPresent(String.self, forKey: .lifecycle))
        minShellVersion =
            try c.decodeIfPresent(String.self, forKey: .minShellVersion)
            ?? c.decodeIfPresent(String.self, forKey: .minShellVersionSnake)
        let raw = try c.decodeIfPresent([String].self, forKey: .viewTypes) ?? []
        viewTypes = try raw.map { token in
            guard let parsed = ViewType(rawValue: token) else {
                throw ManifestLoaderError.unknownViewType(token)
            }
            return parsed
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(version, forKey: .version)
        try c.encode(api, forKey: .api)
        try c.encode(commands, forKey: .commands)
        try c.encode(entrypoint, forKey: .entrypoint)
        try c.encode(cleanup, forKey: .cleanup)
        try c.encode(helpers, forKey: .helpers)
        if !dependencies.isEmpty {
            try c.encode(dependencies, forKey: .dependencies)
        }
        try c.encodeIfPresent(lifecycle?.rawValue, forKey: .lifecycle)
        try c.encodeIfPresent(minShellVersion, forKey: .minShellVersion)
        if !viewTypes.isEmpty {
            try c.encode(viewTypes.map(\.rawValue), forKey: .viewTypes)
        }
    }

    public func validateViewTypes() throws {
        let allowed = allowedViewTypes
        for command in commands {
            if let view = command.view, !allowed.contains(view) {
                throw ManifestLoaderError.commandViewNotAllowed(command: command.id, view: view.rawValue)
            }
        }
    }
}
