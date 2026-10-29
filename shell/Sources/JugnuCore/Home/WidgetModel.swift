import Foundation

public enum WidgetPrimitive: Equatable, Sendable {
    case horizontalStack
    case verticalStack
    case adaptiveGrid
    case spacer
    case divider
    case text
    case image
    case value
    case list
    case progress
    case button
    case toggle
    case radioGroup
    case menu
    case listReorder
    case unsupported
}

public func widgetPrimitive(token: String) -> WidgetPrimitive {
    switch token {
    case "horizontalStack": .horizontalStack
    case "verticalStack": .verticalStack
    case "adaptiveGrid": .adaptiveGrid
    case "spacer": .spacer
    case "divider": .divider
    case "text": .text
    case "image": .image
    case "value": .value
    case "list": .list
    case "progress": .progress
    case "button": .button
    case "toggle": .toggle
    case "radioGroup": .radioGroup
    case "menu": .menu
    case "listReorder": .listReorder
    default: .unsupported
    }
}

public enum WidgetClock: Equatable, Sendable {
    case elapsed(since: Date)
    case remaining(until: Date)
    case civil
}

public struct WidgetValue: Equatable, Sendable {
    public var text: String
    public var clock: WidgetClock?

    public init(text: String, clock: WidgetClock? = nil) {
        self.text = text
        self.clock = clock
    }
}

public enum WidgetSnapshotFailure: String, Codable, Equatable, Sendable {
    case unsupportedPrimitive
    case invalidState
    case timeout
    case disabled
    case malformed
}

public struct WidgetSnapshotRecord: Equatable, Sendable, Codable {
    public var instanceID: String
    public var fetchedAt: Date?
    public var failure: WidgetSnapshotFailure?
    public var hasContent: Bool

    public init(
        instanceID: String,
        fetchedAt: Date?,
        failure: WidgetSnapshotFailure?,
        hasContent: Bool
    ) {
        self.instanceID = instanceID
        self.fetchedAt = fetchedAt
        self.failure = failure
        self.hasContent = hasContent
    }

    public var showsStaleIndicator: Bool {
        hasContent && failure != nil && failure != .disabled
    }
}

public enum WidgetSnapshotSchema {
    public static let supported = 1
}

public struct WidgetSnapshotCache: Equatable, Sendable, Codable {
    public var schemaVersion: Int
    public var records: [WidgetSnapshotRecord]

    public init(schemaVersion: Int, records: [WidgetSnapshotRecord]) {
        self.schemaVersion = schemaVersion
        self.records = records
    }
}

public struct RegistryWidgetSummary: Equatable, Sendable {
    public var name: String
    public var staticPreview: String

    public init(name: String, staticPreview: String) {
        self.name = name
        self.staticPreview = staticPreview
    }
}

public struct AddonWidgetIndex: Equatable, Sendable {
    public var addonID: String
    public var widgets: [RegistryWidgetSummary]

    public init(addonID: String, widgets: [RegistryWidgetSummary]) {
        self.addonID = addonID
        self.widgets = widgets
    }

    public var count: Int {
        widgets.count
    }
}
