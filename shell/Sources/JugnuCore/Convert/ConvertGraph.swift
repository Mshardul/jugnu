import Foundation

/// One enabled addon's way to get from a format to another.
public struct ConvertRoute: Equatable, Sendable {
    public var addonID: String
    public var command: String
    public var from: String
    public var to: String
    public var modes: [ConvertMode]
}

/// The conversion graph the Convert blocks read. Built from enabled addon manifests; rebuild when addons are
/// enabled, disabled, installed or removed. One edge is one hop: there is no chaining.
public struct ConvertGraph: Sendable {
    public let routes: [ConvertRoute]
    private let formatsByID: [String: FormatDecl]

    /// `manifests` are in the user's addon order. That order breaks ties when two addons declare the same edge or
    /// the same extra format; the earlier addon wins.
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

    /// Output formats reachable from `source` in one hop for `mode`, ordered by label.
    public func targets(from source: String, mode: ConvertMode) -> [FormatDecl] {
        var seen = Set<String>()
        return routes
            .filter { $0.from == source && $0.modes.contains(mode) }
            .compactMap { seen.insert($0.to).inserted ? formatsByID[$0.to] : nil }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// Every addon that can do `source → target` for `mode`, in addon order.
    public func routes(from source: String, to target: String, mode: ConvertMode) -> [ConvertRoute] {
        routes.filter { $0.from == source && $0.to == target && $0.modes.contains(mode) }
    }

    /// The route used when the user has not been asked to choose between providers.
    public func route(from source: String, to target: String, mode: ConvertMode) -> ConvertRoute? {
        routes(from: source, to: target, mode: mode).first
    }

    /// Formats that can be converted from at all, for `mode` (the input override dropdown).
    public func sources(mode: ConvertMode) -> [FormatDecl] {
        var seen = Set<String>()
        return routes
            .filter { $0.modes.contains(mode) }
            .compactMap { seen.insert($0.from).inserted ? formatsByID[$0.from] : nil }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
