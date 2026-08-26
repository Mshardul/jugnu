import Foundation

public final class InvokeTrace: @unchecked Sendable {
    public let commandId: String
    private let now: () -> Date
    private let invokeAt: Date
    private var firstPaintAt: Date?
    private var contentAt: Date?
    private var dismissAt: Date?

    public init(commandId: String, now: @escaping () -> Date = { Date() }) {
        self.commandId = commandId
        self.now = now
        self.invokeAt = now()
    }

    public func markFirstPaint() {
        if firstPaintAt == nil {
            firstPaintAt = now()
        }
    }

    public func markContent() {
        contentAt = now()
    }

    public func markDismiss() {
        dismissAt = now()
    }

    public var firstPaintMs: Int? {
        ms(since: invokeAt, to: firstPaintAt)
    }

    public var contentMs: Int? {
        ms(since: invokeAt, to: contentAt)
    }

    public var totalMs: Int? {
        ms(since: invokeAt, to: dismissAt)
    }

    public var debugDescription: String {
        let paint = firstPaintMs.map(String.init) ?? "-"
        let content = contentMs.map(String.init) ?? "-"
        let total = totalMs.map(String.init) ?? "-"
        return "InvokeTrace(\(commandId) firstPaint=\(paint)ms content=\(content)ms total=\(total)ms)"
    }

    public func exceedsToastTarget() -> Bool {
        guard let ms = contentMs ?? firstPaintMs else { return false }
        return ms > LatencyBudgets.toastMs
    }

    private func ms(since start: Date, to end: Date?) -> Int? {
        guard let end else { return nil }
        return Int((end.timeIntervalSince(start) * 1000).rounded())
    }
}

public enum LatencyBudgets {
    public static let palettePaintMs = 50
    public static let toastMs = 150
    public static let chromeMs = 100
    public static let contentMs = 300
    public static let followUpMs = 150

    public static let palettePaintCeilingMs = 100
    public static let toastCeilingMs = 400
    public static let chromeCeilingMs = 200
    public static let contentCeilingMs = 800
    public static let followUpCeilingMs = 400
}
