import Foundation

public struct JugnuState: Codable, Equatable, Sendable {
    public var firstRunCompleted: Bool
    public var recentCommandIDs: [String]
    public var favoriteCommandIDs: [String]

    public init(
        firstRunCompleted: Bool = false,
        recentCommandIDs: [String] = [],
        favoriteCommandIDs: [String] = []
    ) {
        self.firstRunCompleted = firstRunCompleted
        self.recentCommandIDs = recentCommandIDs
        self.favoriteCommandIDs = favoriteCommandIDs
    }

    enum CodingKeys: String, CodingKey {
        case firstRunCompleted
        case recentCommandIDs
        case favoriteCommandIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstRunCompleted = try container.decodeIfPresent(Bool.self, forKey: .firstRunCompleted) ?? false
        recentCommandIDs = try container.decodeIfPresent([String].self, forKey: .recentCommandIDs) ?? []
        favoriteCommandIDs = try container.decodeIfPresent([String].self, forKey: .favoriteCommandIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(firstRunCompleted, forKey: .firstRunCompleted)
        try container.encode(recentCommandIDs, forKey: .recentCommandIDs)
        try container.encode(favoriteCommandIDs, forKey: .favoriteCommandIDs)
    }

    public mutating func recordRecent(qualifiedId: String, limit: Int = 8) {
        recentCommandIDs.removeAll { $0 == qualifiedId }
        recentCommandIDs.insert(qualifiedId, at: 0)
        if recentCommandIDs.count > limit {
            recentCommandIDs = Array(recentCommandIDs.prefix(limit))
        }
    }

    public mutating func toggleFavorite(qualifiedId: String) {
        if let idx = favoriteCommandIDs.firstIndex(of: qualifiedId) {
            favoriteCommandIDs.remove(at: idx)
        } else {
            favoriteCommandIDs.append(qualifiedId)
        }
    }
}

public struct StateStore: Sendable {
    public let paths: JugnuPaths

    public init(paths: JugnuPaths) {
        self.paths = paths
    }

    public func load() throws -> JugnuState {
        guard FileManager.default.fileExists(atPath: paths.stateFile.path) else {
            return JugnuState()
        }
        let data = try Data(contentsOf: paths.stateFile)
        return try JSONDecoder().decode(JugnuState.self, from: data)
    }

    public func save(_ state: JugnuState) throws {
        let parent = paths.stateFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: paths.stateFile, options: .atomic)
    }
}