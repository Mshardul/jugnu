import Foundation

public struct JugnuPaths: Sendable {
    public let home: URL

    public var configFile: URL {
        home.appendingPathComponent(".config/jugnu/jugnu.yaml")
    }

    public var addonsDir: URL {
        home.appendingPathComponent(".local/share/jugnu/addons")
    }

    public var addonsStagingDir: URL {
        addonsDir.appendingPathComponent(".staging")
    }

    public var addonsTrashDir: URL {
        addonsDir.appendingPathComponent(".trash")
    }

    public var helpersDir: URL {
        home.appendingPathComponent(".local/share/jugnu/helpers")
    }

    public var helpersStagingDir: URL {
        helpersDir.appendingPathComponent(".staging")
    }

    public var helpersTrashDir: URL {
        helpersDir.appendingPathComponent(".trash")
    }

    public var stateDir: URL {
        home.appendingPathComponent(".local/share/jugnu/state")
    }

    public var launchAgentsDir: URL {
        home.appendingPathComponent("Library/LaunchAgents")
    }

    public var clockTimersFile: URL {
        stateDir.appendingPathComponent("clock/timers.json")
    }

    public var stateRunDir: URL {
        stateDir.appendingPathComponent("run")
    }

    public var lifecycleLogFile: URL {
        stateDir.appendingPathComponent("lifecycle.log")
    }

    public var crashCounterFile: URL {
        stateDir.appendingPathComponent("launch-attempts")
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
