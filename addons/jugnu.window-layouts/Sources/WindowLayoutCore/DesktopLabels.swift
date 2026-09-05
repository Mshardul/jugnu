import Foundation

public struct DesktopLabels: Equatable, Sendable, Codable {
    public var bySpaceId: [String: String]

    public init(bySpaceId: [String: String] = [:]) {
        self.bySpaceId = bySpaceId
    }
}

public enum DesktopLabelsIO {
    public static func load(from url: URL) throws -> DesktopLabels {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DesktopLabels.self, from: data)
    }

    public static func save(_ labels: DesktopLabels, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(labels)
        try data.write(to: url, options: .atomic)
    }
}
