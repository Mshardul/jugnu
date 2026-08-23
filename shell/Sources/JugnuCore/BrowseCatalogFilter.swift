import Foundation

public enum CatalogSidebarSelection: Hashable, Sendable {
    case all
    case category(String)
    case subcategory(category: String, name: String)

    public var category: String? {
        switch self {
        case .all: return nil
        case .category(let category): return category
        case .subcategory(let category, _): return category
        }
    }

    public var subcategory: String? {
        switch self {
        case .all, .category: return nil
        case .subcategory(_, let name): return name
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
