import Foundation

public struct AppRegistryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var minMacOS: String
    public var url: String
    public var sha256: String
    public var notes: String?

    public init(
        id: String,
        name: String,
        version: String,
        minMacOS: String,
        url: String,
        sha256: String,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.minMacOS = minMacOS
        self.url = url
        self.sha256 = sha256
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, minMacOS, url, sha256, notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        guard id == "jugnu.shell" else {
            throw AppUpdateError.invalidId(id)
        }
        self.id = id
        name = try c.decode(String.self, forKey: .name)
        version = try c.decode(String.self, forKey: .version)
        minMacOS = try c.decode(String.self, forKey: .minMacOS)
        url = try c.decode(String.self, forKey: .url)
        let sha256 = try c.decodeIfPresent(String.self, forKey: .sha256) ?? ""
        if sha256.isEmpty {
            throw AppUpdateError.sha256Required
        }
        self.sha256 = sha256
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(version, forKey: .version)
        try c.encode(minMacOS, forKey: .minMacOS)
        try c.encode(url, forKey: .url)
        try c.encode(sha256, forKey: .sha256)
        try c.encodeIfPresent(notes, forKey: .notes)
    }
}

public enum AppUpdateError: Error, Equatable {
    case sha256Required
    case invalidId(String)
    case invalidRegistryURL
    case versionMismatch(expected: String, actual: String)
    case bundleIdentity
    case destNotWritable
    case helperSpawnFailed
    case macOSTooOld(required: String)
}

public extension RegistryClient {
    func fetchAppRegistry(from url: URL) async throws -> AppRegistryEntry {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw RegistryClientError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(AppRegistryEntry.self, from: data)
        } catch let error as AppUpdateError {
            throw error
        } catch {
            throw RegistryClientError.invalidCatalog
        }
    }
}
