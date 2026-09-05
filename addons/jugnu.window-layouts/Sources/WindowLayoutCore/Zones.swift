import Foundation

public struct DisplayFingerprint: Equatable, Sendable, Codable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct ZoneSlot: Equatable, Sendable, Codable {
    public var displayUUID: String
    public var fingerprint: DisplayFingerprint
    public var norm: NormalizedRect

    public init(displayUUID: String, fingerprint: DisplayFingerprint, norm: NormalizedRect) {
        self.displayUUID = displayUUID
        self.fingerprint = fingerprint
        self.norm = norm
    }
}

public struct Zone: Equatable, Sendable, Codable {
    public var id: String
    public var name: String
    public var slots: [ZoneSlot]

    public init(id: String, name: String, slots: [ZoneSlot]) {
        self.id = id
        self.name = name
        self.slots = slots
    }
}

public struct ZoneStore: Equatable, Sendable, Codable {
    public static let maxCount = 6
    public var zones: [Zone]

    public init(zones: [Zone] = []) {
        self.zones = zones
    }

    public var isFull: Bool { zones.count >= Self.maxCount }

    public mutating func save(_ zone: Zone, replacing id: String? = nil) throws {
        if let id, let idx = zones.firstIndex(where: { $0.id == id }) {
            zones[idx] = Zone(id: id, name: zone.name, slots: zone.slots)
            return
        }
        if isFull {
            throw ZoneStoreError.full
        }
        zones.append(zone)
    }

    public mutating func delete(id: String) {
        zones.removeAll { $0.id == id }
    }

    public func zone(id: String) -> Zone? {
        zones.first { $0.id == id }
    }
}

public enum ZoneStoreError: Error, Equatable {
    case full
}

public enum ZoneStoreIO {
    public static func load(from url: URL) throws -> ZoneStore {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ZoneStore.self, from: data)
    }

    public static func save(_ store: ZoneStore, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(store)
        try data.write(to: url, options: .atomic)
    }
}
