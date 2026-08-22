import Foundation

public struct JugnuConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var shell: ShellConfig
    public var addons: [String: AddonConfig]
    public var ui: [String: String]

    public init(
        version: Int = 1,
        shell: ShellConfig = ShellConfig(),
        addons: [String: AddonConfig] = [:],
        ui: [String: String] = [:]
    ) {
        self.version = version
        self.shell = shell
        self.addons = addons
        self.ui = ui
    }
}

public struct ShellConfig: Codable, Equatable, Sendable {
    public var hotkey: String
    /// Catalog JSON URL (GitHub raw or release-pinned).
    public var registryURL: String

    public static let defaultRegistryURL =
        "https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/addons.json"

    public static let recommendedAddonIDs = ["mic-mute", "focus-toggle", "paste-plain"]

    public init(
        hotkey: String = "option+space",
        registryURL: String = ShellConfig.defaultRegistryURL
    ) {
        self.hotkey = hotkey
        self.registryURL = registryURL
    }

    enum CodingKeys: String, CodingKey {
        case hotkey
        case registryURL = "registry_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? "option+space"
        registryURL = try c.decodeIfPresent(String.self, forKey: .registryURL) ?? Self.defaultRegistryURL
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

    public init(
        id: String,
        title: String,
        subtitle: String,
        keywords: [String] = [],
        ui: CommandUISpec? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.ui = ui
    }

    public var defaultUIPattern: UIPattern? { ui?.pattern }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        ui = try c.decodeIfPresent(CommandUISpec.self, forKey: .ui)
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

public struct AddonManifest: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var api: Int
    public var commands: [CommandDescriptor]
    public var entrypoint: Entrypoint
    public var cleanup: CleanupSpec

    public init(
        id: String,
        name: String,
        version: String,
        api: Int,
        commands: [CommandDescriptor],
        entrypoint: Entrypoint,
        cleanup: CleanupSpec = CleanupSpec()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.api = api
        self.commands = commands
        self.entrypoint = entrypoint
        self.cleanup = cleanup
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
    }
}
