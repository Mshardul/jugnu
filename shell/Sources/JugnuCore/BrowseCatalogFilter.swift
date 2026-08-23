import Foundation

public func filterCatalog(
    entries: [RegistryEntry],
    category: String?,
    tags: Set<String>,
    search: String
) -> [RegistryEntry] {
    var result = entries
    if let category {
        result = result.filter { $0.category == category }
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
