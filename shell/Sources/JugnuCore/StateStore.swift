import Foundation

public struct JugnuState: Codable, Equatable, Sendable {
    public var firstRunCompleted: Bool

    public init(firstRunCompleted: Bool = false) {
        self.firstRunCompleted = firstRunCompleted
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
