import Foundation

public struct RegistryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var api: Int
    public var url: String
    public var sha256: String
    public var summary: String

    public init(
        id: String,
        name: String,
        version: String,
        api: Int,
        url: String,
        sha256: String,
        summary: String
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.api = api
        self.url = url
        self.sha256 = sha256
        self.summary = summary
    }
}

public struct RegistryClient: Sendable {
    public init() {}

    public func fetch(from url: URL) async throws -> [RegistryEntry] {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RegistryClientError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode([RegistryEntry].self, from: data)
    }
}

public enum RegistryClientError: Error, Equatable {
    case httpStatus(Int)
}
