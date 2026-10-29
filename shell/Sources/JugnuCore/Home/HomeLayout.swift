import Foundation

public enum HomeLayoutSchema {
    public static let supported = 1
}

public enum BuiltInWidget {
    public static let favoriteAddons = "jugnu.widgets.favorite-addons"
    public static let recentActivity = "jugnu.widgets.recent-activity"
    public static let updates = "jugnu.widgets.updates"
    public static let runningWork = "jugnu.widgets.running-work"
}

public enum WidgetDefinitionIssue: Equatable, Sendable {
    case nonPositiveSpan
    case maxBelowMin
    case defaultOutsideLimits
    case oneColumnFallbackUnsupported
}

public struct WidgetDefinition: Equatable, Sendable {
    public var id: String
    public var name: String
    public var limits: WidgetSpanLimits
    public var defaultWidth: ExactRational
    public var defaultRows: Int
    public var rendersInOneColumn: Bool

    public init(
        id: String,
        name: String,
        limits: WidgetSpanLimits,
        defaultWidth: ExactRational,
        defaultRows: Int,
        rendersInOneColumn: Bool
    ) {
        self.id = id
        self.name = name
        self.limits = limits
        self.defaultWidth = defaultWidth
        self.defaultRows = defaultRows
        self.rendersInOneColumn = rendersInOneColumn
    }
}

public enum WidgetConfigValue: Equatable, Sendable, Codable {
    case text(String)
    case flag(Bool)
    case choice(String)
}

public struct WidgetConfiguration: Equatable, Sendable, Codable {
    public var values: [String: WidgetConfigValue]

    public init(values: [String: WidgetConfigValue] = [:]) {
        self.values = values
    }
}

public struct HomeWidgetInstance: Equatable, Sendable, Codable {
    public var id: String
    public var definitionID: String
    public var preferredWidth: ExactRational
    public var preferredRows: Int
    public var configuration: WidgetConfiguration

    public init(
        id: String,
        definitionID: String,
        preferredWidth: ExactRational,
        preferredRows: Int,
        configuration: WidgetConfiguration = WidgetConfiguration()
    ) {
        self.id = id
        self.definitionID = definitionID
        self.preferredWidth = preferredWidth
        self.preferredRows = preferredRows
        self.configuration = configuration
    }
}

public struct HomeLayoutSnapshot: Equatable, Sendable, Codable {
    public var schemaVersion: Int
    public var instances: [HomeWidgetInstance]

    public init(schemaVersion: Int, instances: [HomeWidgetInstance]) {
        self.schemaVersion = schemaVersion
        self.instances = instances
    }
}

public enum HomeLayoutRead: Equatable, Sendable {
    case missing
    case ready(HomeLayoutSnapshot)
    case newer(schemaVersion: Int)
    case unreadable
}

public enum HomeLayoutMutation: Equatable, Sendable {
    case written
    case leftUntouched
}

public struct HomeLayoutStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func read() -> HomeLayoutRead {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .missing }
        guard let data = try? Data(contentsOf: fileURL) else { return .unreadable }
        return Self.read(data)
    }

    public func write(_ snapshot: HomeLayoutSnapshot) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    public func mutate(_ body: (inout HomeLayoutSnapshot) -> Void) throws -> HomeLayoutMutation {
        switch read() {
        case .newer, .unreadable:
            return .leftUntouched
        case .missing:
            var snapshot = defaultHomeLayout()
            body(&snapshot)
            try write(snapshot)
            return .written
        case let .ready(existing):
            var snapshot = existing
            body(&snapshot)
            try write(snapshot)
            return .written
        }
    }

    static func read(_ data: Data) -> HomeLayoutRead {
        guard let header = try? JSONDecoder().decode(SchemaHeader.self, from: data) else {
            return .unreadable
        }
        if header.schemaVersion > HomeLayoutSchema.supported {
            return .newer(schemaVersion: header.schemaVersion)
        }
        guard let snapshot = try? JSONDecoder().decode(HomeLayoutSnapshot.self, from: data),
              snapshot.schemaVersion <= HomeLayoutSchema.supported
        else {
            return .unreadable
        }
        return .ready(snapshot)
    }
}

public func widgetDefinitionIssues(_ definition: WidgetDefinition) -> [WidgetDefinitionIssue] {
    var issues: [WidgetDefinitionIssue] = []
    let limits = definition.limits
    if limits.minColumns < 1 || limits.minRows < 1 || limits.maxColumns < 1 || limits.maxRows < 1 {
        issues.append(.nonPositiveSpan)
    }
    if limits.maxColumns < limits.minColumns || limits.maxRows < limits.minRows {
        issues.append(.maxBelowMin)
    }
    if definition.defaultRows < limits.minRows
        || definition.defaultRows > limits.maxRows
        || definition.defaultWidth.numerator <= 0
    {
        issues.append(.defaultOutsideLimits)
    }
    if limits.minColumns > 1, !definition.rendersInOneColumn {
        issues.append(.oneColumnFallbackUnsupported)
    }
    return issues
}

public func builtInWidgetDefinitions() -> [WidgetDefinition] {
    [
        builtIn(BuiltInWidget.favoriteAddons, name: "Favorite Addons", rows: 3),
        builtIn(BuiltInWidget.recentActivity, name: "Recent Activity", rows: 3),
        builtIn(BuiltInWidget.updates, name: "Updates", rows: 2),
        builtIn(BuiltInWidget.runningWork, name: "Running Work", rows: 2)
    ]
}

public func defaultHomeLayout() -> HomeLayoutSnapshot {
    HomeLayoutSnapshot(
        schemaVersion: HomeLayoutSchema.supported,
        instances: [
            instance(BuiltInWidget.favoriteAddons, id: "home.favorite-addons", rows: 3),
            instance(BuiltInWidget.recentActivity, id: "home.recent-activity", rows: 3),
            instance(BuiltInWidget.updates, id: "home.updates", rows: 2)
        ]
    )
}

private struct SchemaHeader: Decodable {
    var schemaVersion: Int
}

private func builtIn(_ id: String, name: String, rows: Int) -> WidgetDefinition {
    WidgetDefinition(
        id: id,
        name: name,
        limits: WidgetSpanLimits(minColumns: 2, maxColumns: 12, minRows: 1, maxRows: 8),
        defaultWidth: ExactRational(1, 2),
        defaultRows: rows,
        rendersInOneColumn: true
    )
}

private func instance(_ definitionID: String, id: String, rows: Int) -> HomeWidgetInstance {
    HomeWidgetInstance(
        id: id,
        definitionID: definitionID,
        preferredWidth: ExactRational(1, 2),
        preferredRows: rows
    )
}
