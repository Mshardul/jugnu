import Foundation

public struct JugnuPaths: Sendable {
    public let home: URL

    public var configFile: URL {
        home.appendingPathComponent(".config/jugnu/jugnu.yaml")
    }

    public var addonsDir: URL {
        home.appendingPathComponent(".local/share/jugnu/addons")
    }

    public var stateFile: URL {
        home.appendingPathComponent(".config/jugnu/state.json")
    }

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }
}
