import Foundation
import Yams

public struct ConfigStore: Sendable {
    public let paths: JugnuPaths

    public init(paths: JugnuPaths) {
        self.paths = paths
    }

    public func load() throws -> JugnuConfig {
        let data = try Data(contentsOf: paths.configFile)
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ConfigStoreError.invalidEncoding
        }
        return try YAMLDecoder().decode(JugnuConfig.self, from: yaml)
    }

    public func save(_ config: JugnuConfig) throws {
        let parent = paths.configFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let yaml = try YAMLEncoder().encode(config)
        try yaml.write(to: paths.configFile, atomically: true, encoding: .utf8)
    }

    public func loadOrCreateDefaults() throws -> JugnuConfig {
        if FileManager.default.fileExists(atPath: paths.configFile.path) {
            return try load()
        }
        let config = JugnuConfig()
        try save(config)
        return config
    }
}

public enum ConfigStoreError: Error, Equatable {
    case invalidEncoding
}
