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

    public init(
        id: String, name: String, version: String, api: Int, url: String, sha256: String, summary: String,
        category: String, subcategory: String? = nil, tags: [String] = [],
        description: String? = nil, commands: [RegistryCommand] = []
    ) {
        self.id = id; self.name = name; self.version = version; self.api = api
        self.url = url; self.sha256 = sha256; self.summary = summary
        self.category = category; self.subcategory = subcategory; self.tags = tags
        self.description = description; self.commands = commands
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, api, url, sha256, summary, category, subcategory, tags, description, commands
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
    }
}

extension RegistryEntry: Identifiable {}

public struct RegistryClient: Sendable {
    public init() {}

    public func fetch(from url: URL) async throws -> [RegistryEntry] {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
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
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
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
