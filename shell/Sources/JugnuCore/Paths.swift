import Foundation

public struct JugnuPaths: Sendable {
    public let home: URL

    public var configFile: URL {
        home.appendingPathComponent(".config/jugnu/jugnu.yaml")
    }

    public var addonsDir: URL {
        home.appendingPathComponent(".local/share/jugnu/addons")
    }

    public var helpersDir: URL {
        home.appendingPathComponent(".local/share/jugnu/helpers")
    }

    public func helperRoot(id: String, version: String) -> URL {
        helpersDir.appendingPathComponent(id).appendingPathComponent(version)
    }

    public var stateFile: URL {
        home.appendingPathComponent(".config/jugnu/state.json")
    }

    public var registryCacheFile: URL {
        home.appendingPathComponent(".local/share/jugnu/state/registry-cache.json")
    }

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }
}
