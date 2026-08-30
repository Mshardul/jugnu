import Foundation

public struct RunningInstance: Sendable, Equatable {
    public let pid: Int
    public let launchDate: Date?

    public init(pid: Int, launchDate: Date?) {
        self.pid = pid
        self.launchDate = launchDate
    }
}

public enum SingleInstance {
    public static let openPaletteNotification = Notification.Name("com.jugnu.open-palette")

    /// The oldest instance owns the hotkey and menu bar; ties break to the lower pid.
    public static func shouldYield(running: [RunningInstance], selfPID: Int) -> Bool {
        guard let me = running.first(where: { $0.pid == selfPID }) else { return false }
        return running.contains { other in
            other.pid != selfPID && ranksAhead(other, of: me)
        }
    }

    private static func ranksAhead(_ a: RunningInstance, of b: RunningInstance) -> Bool {
        switch (a.launchDate, b.launchDate) {
        case let (x?, y?) where x != y:
            x < y
        default:
            a.pid < b.pid
        }
    }
}
