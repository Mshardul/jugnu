import Foundation

public struct RunMarker: Codable, Equatable, Sendable {
    public var origin: String
    public var lifecycleClass: String
    public var shellPID: Int32
    public var shellStartTS: Double
    public var spawnedAt: Double

    enum CodingKeys: String, CodingKey {
        case origin
        case lifecycleClass = "class"
        case shellPID = "shell_pid"
        case shellStartTS = "shell_start_ts"
        case spawnedAt = "spawned_at"
    }

    public init(
        origin: String,
        lifecycleClass: String,
        shellPID: Int32,
        shellStartTS: Double,
        spawnedAt: Double
    ) {
        self.origin = origin
        self.lifecycleClass = lifecycleClass
        self.shellPID = shellPID
        self.shellStartTS = shellStartTS
        self.spawnedAt = spawnedAt
    }

    public static func write(_ marker: RunMarker, pid: Int32, to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(marker)
        let target = dir.appendingPathComponent("\(pid).json")
        let tmp = dir.appendingPathComponent(".\(pid).\(UUID().uuidString).tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: target)
        }
        try FileManager.default.moveItem(at: tmp, to: target)
    }

    public static func delete(pid: Int32, in dir: URL) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(pid).json"))
    }

    public static func enumerate(in dir: URL) -> [(pid: Int32, marker: RunMarker?)] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        var out: [(pid: Int32, marker: RunMarker?)] = []
        for url in entries where url.pathExtension == "json" {
            let name = url.deletingPathExtension().lastPathComponent
            guard let pid = Int32(name) else { continue }
            let marker = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(RunMarker.self, from: $0) }
            out.append((pid: pid, marker: marker))
        }
        return out
    }
}
