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

    fileprivate func using(file: String) -> ClockRequest {
        ClockRequest(
            op: op,
            file: file,
            timer: timer,
            id: id,
            group: group,
            now: now,
            seconds: seconds
        )
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

public struct ClockClient: Sendable {
    public static let helperVersion = "1.0.0"

    public let paths: JugnuPaths

    public init(paths: JugnuPaths = JugnuPaths()) {
        self.paths = paths
    }

    public var executableURL: URL {
        paths.helperRoot(id: "clock", version: Self.helperVersion)
            .appendingPathComponent("bin/clock")
    }

    public func run(_ request: ClockRequest) throws -> ClockResponse {
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        process.executableURL = executableURL
        process.standardInput = stdin
        process.standardOutput = stdout

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request.using(file: paths.clockTimersFile.path))

        do {
            try process.run()
        } catch {
            throw ClockClientError.unavailable
        }
        stdin.fileHandleForWriting.write(data)
        stdin.fileHandleForWriting.write(Data([0x0A]))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(
                ClockResponse.self,
                from: stdout.fileHandleForReading.readDataToEndOfFile()
            )
        } catch {
            throw ClockClientError.invalidResponse
        }
    }
}

public enum ClockClientError: Error, Equatable {
    case unavailable
    case invalidResponse
    case requestFailed
}

public struct ClockService: ClockServicing {
    private let client: ClockClient

    public init(client: ClockClient = ClockClient()) {
        self.client = client
    }

    public func due(now: Date) throws -> [ClockTimer] {
        guard FileManager.default.isExecutableFile(atPath: client.executableURL.path) else {
            return []
        }
        let response = try client.run(ClockRequest(op: .due, now: now))
        guard response.ok else { throw ClockClientError.requestFailed }
        return response.timers ?? []
    }

    public func markFired(id: String, now: Date) throws {
        let response = try client.run(ClockRequest(op: .markFired, id: id, now: now))
        guard response.ok else { throw ClockClientError.requestFailed }
    }
}
