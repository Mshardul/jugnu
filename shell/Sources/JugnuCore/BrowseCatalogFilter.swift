import Foundation

public enum CatalogSidebarSelection: Hashable, Sendable {
    case all
    case category(String)
    case subcategory(category: String, name: String)

    public var category: String? {
        switch self {
        case .all: nil
        case let .category(category): category
        case let .subcategory(category, _): category
        }
    }

    public var subcategory: String? {
        switch self {
        case .all, .category: nil
        case let .subcategory(_, name): name
        }
    }
}

public func filterCatalog(
    entries: [RegistryEntry],
    category: String?,
    subcategory: String? = nil,
    tags: Set<String>,
    search: String
) -> [RegistryEntry] {
    var result = entries
    if let category {
        result = result.filter { $0.category == category }
    }
    if let subcategory {
        result = result.filter { $0.subcategory == subcategory }
    }
    if !tags.isEmpty {
        result = result.filter { tags.isSubset(of: Set($0.tags)) }
    }
    let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
        result = result.filter { entry in
            let haystacks = [entry.name, entry.summary] + entry.tags
            return haystacks.contains { Fuzzy.score(query: trimmed, in: $0) > 0 }
        }
    }
    return result
}

public func catalogWithSymlinkedAddons(_ fetched: [RegistryEntry], symlinked: [RegistryEntry]) -> [RegistryEntry] {
    let known = Set(fetched.map(\.id))
    return fetched + symlinked.filter { !known.contains($0.id) }
}

public func registryEntryForLocalAddon(_ manifest: AddonManifest) -> RegistryEntry {
    RegistryEntry(
        id: manifest.id,
        name: manifest.name,
        version: manifest.version,
        api: manifest.api,
        url: "local:\(manifest.id)",
        sha256: "local",
        summary: manifest.commands.first?.title ?? manifest.name,
        category: "System",
        description: manifest.commands.first?.subtitle,
        commands: manifest.commands.map {
            RegistryCommand(id: $0.id, title: $0.title, subtitle: $0.subtitle)
        },
        permissions: manifest.permissions,
        primary: manifest.primary
    )
}

/// ignores the active tag filter so chips show what's still selectable, not the full vocabulary
public func availableTags(
    entries: [RegistryEntry],
    category: String?,
    subcategory: String? = nil,
    search: String
) -> Set<String> {
    let scoped = filterCatalog(entries: entries, category: category, subcategory: subcategory, tags: [], search: search)
    return scoped.reduce(into: Set<String>()) { $0.formUnion($1.tags) }
}
