import Foundation

public struct RegistryCommand: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String

    public init(id: String, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public struct RegistryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var api: Int
    public var url: String
    public var sha256: String
    public var summary: String
    public var category: String
    public var subcategory: String?
    public var tags: [String]
    public var description: String?
    public var commands: [RegistryCommand]
    // catalog-side copies of the manifest fields, so disclosure works before download
    public var dependencies: [AddonDependency]
    public var permissions: [AddonPermission]
    public var primary: String?

    public init(
        id: String, name: String, version: String, api: Int, url: String, sha256: String, summary: String,
        category: String, subcategory: String? = nil, tags: [String] = [],
        description: String? = nil, commands: [RegistryCommand] = [],
        dependencies: [AddonDependency] = [],
        permissions: [AddonPermission] = [],
        primary: String? = nil
    ) {
        self.id = id; self.name = name; self.version = version; self.api = api
        self.url = url; self.sha256 = sha256; self.summary = summary
        self.category = category; self.subcategory = subcategory; self.tags = tags
        self.description = description; self.commands = commands
        self.dependencies = dependencies
        self.permissions = permissions
        self.primary = primary
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, api, url, sha256, summary, category, subcategory, tags, description, commands
        case dependencies, permissions, primary
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        version = try c.decode(String.self, forKey: .version)
        api = try c.decode(Int.self, forKey: .api)
        url = try c.decode(String.self, forKey: .url)
        sha256 = try c.decode(String.self, forKey: .sha256)
        summary = try c.decode(String.self, forKey: .summary)
        category = try c.decode(String.self, forKey: .category)
        subcategory = try c.decodeIfPresent(String.self, forKey: .subcategory)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        description = try c.decodeIfPresent(String.self, forKey: .description)
        commands = try c.decodeIfPresent([RegistryCommand].self, forKey: .commands) ?? []
        dependencies = try c.decodeIfPresent([AddonDependency].self, forKey: .dependencies) ?? []
        primary = try c.decodeIfPresent(String.self, forKey: .primary)
        do {
            permissions = try PermissionsSet.parse(c.decodeIfPresent([String].self, forKey: .permissions) ?? [])
        } catch is PermissionsParseError {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: c.codingPath + [CodingKeys.permissions], debugDescription: "unknown permission")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(version, forKey: .version)
        try c.encode(api, forKey: .api)
        try c.encode(url, forKey: .url)
        try c.encode(sha256, forKey: .sha256)
        try c.encode(summary, forKey: .summary)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(subcategory, forKey: .subcategory)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(commands, forKey: .commands)
        if !dependencies.isEmpty {
            try c.encode(dependencies, forKey: .dependencies)
        }
        if !permissions.isEmpty {
            try c.encode(permissions.map(\.rawValue), forKey: .permissions)
        }
        try c.encodeIfPresent(primary, forKey: .primary)
    }
}

extension RegistryEntry: Identifiable {}

public struct RegistryClient: Sendable {
    public init() {}

    public func fetch(from url: URL) async throws -> [RegistryEntry] {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw RegistryClientError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode([RegistryEntry].self, from: data)
        } catch {
            throw RegistryClientError.invalidCatalog
        }
    }

    public func fetchHelpers(from url: URL) async throws -> [HelperRegistryEntry] {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw RegistryClientError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode([HelperRegistryEntry].self, from: data)
        } catch {
            throw RegistryClientError.invalidCatalog
        }
    }
}

public struct HelperRegistryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var version: String
    public var url: String
    public var sha256: String

    public init(id: String, version: String, url: String, sha256: String) {
        self.id = id
        self.version = version
        self.url = url
        self.sha256 = sha256
    }
}

public enum RegistryClientError: Error, Equatable {
    case httpStatus(Int)
    case invalidCatalog
}
