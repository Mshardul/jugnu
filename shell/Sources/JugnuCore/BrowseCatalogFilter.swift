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

/// Tags present in the current category/subcategory/search scope, ignoring the
/// tag filter itself so chips reflect what's actually selectable, not the full vocabulary.
public func availableTags(
    entries: [RegistryEntry],
    category: String?,
    subcategory: String? = nil,
    search: String
) -> Set<String> {
    let scoped = filterCatalog(entries: entries, category: category, subcategory: subcategory, tags: [], search: search)
    return scoped.reduce(into: Set<String>()) { $0.formUnion($1.tags) }
}
