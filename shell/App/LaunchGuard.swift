import Foundation

final class LaunchGuard {
    private let fileURL: URL
    private let now: () -> Date
    private(set) var count: Int

    init(fileURL: URL, now: @escaping () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.now = now
        self.count = Self.readCount(fileURL)
    }

    var shouldEnterSafeMode: Bool {
        count >= 3
    }

    func recordAttempt() {
        count += 1
        writeCount(count)
    }

    func markCleanLaunch() {
        count = 0
        writeCount(0)
    }

    private static func readCount(_ fileURL: URL) -> Int {
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return 0 }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else { return 0 }
        return value
    }

    private func writeCount(_ value: Int) {
        let parent = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let tmp = parent.appendingPathComponent(".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")
        try? String(value).write(to: tmp, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.moveItem(at: tmp, to: fileURL)
    }
}

enum RecoveryReason: Equatable {
    case crashLoop
    case malformedConfig
}

enum LaunchStart: Equatable {
    case normal
    case recovery(RecoveryReason)

    static func decide(safeMode: Bool, configSyntaxError: Bool) -> LaunchStart {
        if configSyntaxError { return .recovery(.malformedConfig) }
        if safeMode { return .recovery(.crashLoop) }
        return .normal
    }
}

enum RecoveryMenuCopy {
    static let resetConfig = "Reset config to defaults"
    static let openConfig = "Open config file"
    static let disableAddons = "Disable all addons"
    static let tryAgain = "Try normal launch again"
}
