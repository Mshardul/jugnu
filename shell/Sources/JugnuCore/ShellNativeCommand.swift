import Foundation

/// Mandatory palette rows ("built-in addons"): not zips, not toggles; only jugnu.yaml hides them.
public struct ShellNativeCommand: Identifiable, Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case browseAddons = "browse-addons"
        case preferences
    }

    public let kind: Kind
    public var title: String
    public var subtitle: String
    public var keywords: [String]
    public var systemImage: String

    public var id: String {
        kind.rawValue
    }

    public static let all: [ShellNativeCommand] = [
        ShellNativeCommand(
            kind: .browseAddons,
            title: "Browse Addons",
            subtitle: "Discover and install addons",
            keywords: ["browse", "addons", "catalog", "install", "discover", "store"],
            systemImage: "square.grid.2x2"
        ),
        ShellNativeCommand(
            kind: .preferences,
            title: "Preferences",
            subtitle: "Theme, hotkey, addon settings",
            keywords: ["preferences", "settings", "theme", "hotkey", "config", "options"],
            systemImage: "gearshape"
        )
    ]

    public static func visible(hidden: Set<String>) -> [ShellNativeCommand] {
        all.filter { !hidden.contains($0.id) }
    }

    public func matchScore(query: String) -> Int {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let haystacks = [title, subtitle] + keywords
        return haystacks.map { Fuzzy.score(query: trimmed, in: $0) }.max() ?? 0
    }
}
