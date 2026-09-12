import Foundation

public enum FirstRunSelection {
    public static func precheckedIDs(entries: [RegistryEntry], fallback: [String]) -> [String] {
        let tagged = entries.filter { $0.tags.contains("recommended") }.map(\.id)
        if !tagged.isEmpty {
            return tagged
        }
        let catalog = Set(entries.map(\.id))
        return fallback.filter { catalog.contains($0) }
    }
}
