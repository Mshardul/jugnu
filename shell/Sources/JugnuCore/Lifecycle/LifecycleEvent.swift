import Foundation

public struct LifecycleEvent: Codable, Equatable, Sendable {
    public var event: String
    public var origin: String?
    public var reason: String?
    public var strikeCount: Int?
    public var ts: Double

    enum CodingKeys: String, CodingKey {
        case event
        case origin
        case reason
        case strikeCount = "strike_count"
        case ts
    }

    public init(
        event: String,
        origin: String? = nil,
        reason: String? = nil,
        strikeCount: Int? = nil,
        ts: Double
    ) {
        self.event = event
        self.origin = origin
        self.reason = reason
        self.strikeCount = strikeCount
        self.ts = ts
    }

    var alwaysRecorded: Bool {
        event == "reap" || event == "safe_mode"
    }
}

public struct LifecycleLog: Sendable {
    private let fileURL: URL
    private let now: @Sendable () -> Date
    private let cap = 200

    public init(fileURL: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.now = now
    }

    public func record(_ event: LifecycleEvent) {
        #if !DEBUG
            guard event.alwaysRecorded else { return }
        #endif
        guard let line = try? JSONEncoder().encode(event),
              let lineStr = String(data: line, encoding: .utf8) else { return }
        var lines: [String] = []
        if let existing = try? String(contentsOf: fileURL, encoding: .utf8) {
            lines = existing.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        }
        lines.append(lineStr)
        if lines.count > cap {
            lines = Array(lines.suffix(cap))
        }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? (lines.joined(separator: "\n") + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    public func recordNow(event: String, origin: String? = nil, reason: String? = nil, strikeCount: Int? = nil) {
        record(LifecycleEvent(
            event: event,
            origin: origin,
            reason: reason,
            strikeCount: strikeCount,
            ts: now().timeIntervalSince1970
        ))
    }
}
