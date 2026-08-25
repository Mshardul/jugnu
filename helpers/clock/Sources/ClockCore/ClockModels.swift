import Foundation

public struct ClockTarget: Codable, Equatable, Sendable {
    public let addon: String
    public let command: String

    public init(addon: String, command: String) {
        self.addon = addon
        self.command = command
    }
}

public struct ClockTimer: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case interval
        case oneShot = "one-shot"
    }

    public let id: String
    public let kind: Kind
    public let intervalSeconds: Int?
    public let fireAt: Date?
    public let enabled: Bool
    public let paused: Bool
    public let nextFire: Date
    public let group: String?
    public let target: ClockTarget

    public init(
        id: String,
        kind: Kind,
        intervalSeconds: Int?,
        fireAt: Date?,
        enabled: Bool,
        paused: Bool,
        nextFire: Date,
        group: String?,
        target: ClockTarget
    ) {
        self.id = id
        self.kind = kind
        self.intervalSeconds = intervalSeconds
        self.fireAt = fireAt
        self.enabled = enabled
        self.paused = paused
        self.nextFire = nextFire
        self.group = group
        self.target = target
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case intervalSeconds = "interval_seconds"
        case fireAt = "fire_at"
        case enabled
        case paused
        case nextFire = "next_fire"
        case group
        case target
    }
}

public enum ClockOp: String, Codable, Sendable {
    case upsert
    case cancel
    case pause
    case resume
    case list
    case due
    case markFired = "mark-fired"
    case snooze
}

public struct ClockRequest: Codable, Equatable, Sendable {
    public let op: ClockOp
    public let file: String?
    public let timer: ClockTimer?
    public let id: String?
    public let group: String?
    public let now: Date?
    public let seconds: Int?

    public init(
        op: ClockOp,
        file: String? = nil,
        timer: ClockTimer? = nil,
        id: String? = nil,
        group: String? = nil,
        now: Date? = nil,
        seconds: Int? = nil
    ) {
        self.op = op
        self.file = file
        self.timer = timer
        self.id = id
        self.group = group
        self.now = now
        self.seconds = seconds
    }
}

public struct ClockResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let timers: [ClockTimer]?
    public let error: String?

    public init(ok: Bool, timers: [ClockTimer]? = nil, error: String? = nil) {
        self.ok = ok
        self.timers = timers
        self.error = error
    }
}
