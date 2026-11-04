import Foundation

public struct ConvertRoute: Equatable, Sendable {
    public var addonID: String
    public var command: String
    public var from: String
    public var to: String
    public var modes: [ConvertMode]
}

public struct ConvertGraph: Sendable {
    public let routes: [ConvertRoute]
    private let formatsByID: [String: FormatDecl]

    public init(manifests: [AddonManifest]) {
        var formats: [String: FormatDecl] = [:]
        for format in FormatCatalog.core {
            formats[format.id] = format
        }
        var routes: [ConvertRoute] = []
        for manifest in manifests {
            for format in manifest.formats where formats[format.id] == nil {
                formats[format.id] = format
            }
            for edge in manifest.converters {
                routes.append(ConvertRoute(
                    addonID: manifest.id,
                    command: edge.command,
                    from: edge.from,
                    to: edge.to,
                    modes: edge.modes
                ))
            }
        }
        self.routes = routes
        formatsByID = formats
    }

    public var formats: [FormatDecl] {
        formatsByID.values.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    public func format(id: String) -> FormatDecl? {
        formatsByID[id]
    }

    public func targets(from source: String, mode: ConvertMode) -> [FormatDecl] {
        var seen = Set<String>()
        return routes
            .filter { $0.from == source && $0.modes.contains(mode) }
            .compactMap { seen.insert($0.to).inserted ? formatsByID[$0.to] : nil }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    public func routes(from source: String, to target: String, mode: ConvertMode) -> [ConvertRoute] {
        routes.filter { $0.from == source && $0.to == target && $0.modes.contains(mode) }
    }

    public func route(from source: String, to target: String, mode: ConvertMode) -> ConvertRoute? {
        routes(from: source, to: target, mode: mode).first
    }

    public func sources(mode: ConvertMode) -> [FormatDecl] {
        var seen = Set<String>()
        return routes
            .filter { $0.modes.contains(mode) }
            .compactMap { seen.insert($0.from).inserted ? formatsByID[$0.from] : nil }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
