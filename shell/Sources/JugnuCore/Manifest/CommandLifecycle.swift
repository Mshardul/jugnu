import Foundation

public enum OnReinvoke: String, Codable, Equatable, Sendable {
    case reuse
    case replace
}

public struct DaemonBlock: Codable, Equatable, Sendable {
    public var program: String
    public var args: [String]?
    public var keepAlive: Bool?

    public init(program: String, args: [String]? = nil, keepAlive: Bool? = nil) {
        self.program = program
        self.args = args
        self.keepAlive = keepAlive
    }

    enum CodingKeys: String, CodingKey {
        case program
        case args
        case keepAlive = "keep_alive"
    }
}

public extension LifecycleClass {
    static func decodeManifestValue(_ raw: String?) throws -> LifecycleClass? {
        guard let raw else { return nil }
        if raw == "session" {
            throw ManifestLoaderError.sessionNotSupported
        }
        guard let parsed = LifecycleClass(rawValue: raw) else {
            throw ManifestLoaderError.unknownLifecycleClass(raw)
        }
        return parsed
    }
}
