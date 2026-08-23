import XCTest
@testable import JugnuCore

final class BrowseCatalogFilterTests: XCTestCase {
    private func entry(
        _ id: String, category: String, tags: [String], name: String? = nil, summary: String = "",
        subcategory: String? = nil
    ) -> RegistryEntry {
        RegistryEntry(
            id: id, name: name ?? id, version: "1.0.0", api: 1, url: "https://x/\(id).zip", sha256: "x",
            summary: summary, category: category, subcategory: subcategory, tags: tags
        )
    }

    func testNilCategoryReturnsAll() {
        let entries = [entry("a", category: "System", tags: []), entry("b", category: "Focus", tags: [])]
        XCTAssertEqual(filterCatalog(entries: entries, category: nil, tags: [], search: "").count, 2)
    }

    func testCategoryFiltersToMatchingOnly() {
        let entries = [entry("a", category: "System", tags: []), entry("b", category: "Focus", tags: [])]
        let result = filterCatalog(entries: entries, category: "Focus", tags: [], search: "")
        XCTAssertEqual(result.map(\.id), ["b"])
    }

    func testTagsRequireAllSelectedTagsPresent() {
        let entries = [
            entry("a", category: "System", tags: ["popup-ui", "dev-tool"]),
            entry("b", category: "System", tags: ["popup-ui"]),
        ]
        let result = filterCatalog(entries: entries, category: nil, tags: ["popup-ui", "dev-tool"], search: "")
        XCTAssertEqual(result.map(\.id), ["a"])
    }

    func testSearchComposesWithCategoryAndTags() {
        let entries = [
            entry("ports", category: "System", tags: ["dev-tool"], name: "Ports", summary: "kill by pid"),
            entry("brew-outdated", category: "System", tags: ["dev-tool"], name: "Brew Outdated", summary: "outdated packages"),
        ]
        let result = filterCatalog(entries: entries, category: "System", tags: ["dev-tool"], search: "port")
        XCTAssertEqual(result.map(\.id), ["ports"])
    }

    func testEmptySearchDoesNotFilterOutAnything() {
        let entries = [entry("a", category: "System", tags: [])]
        XCTAssertEqual(filterCatalog(entries: entries, category: nil, tags: [], search: "").count, 1)
    }

    func testSubcategoryFiltersWithinCategory() {
        let entries = [
            entry("ports", category: "System", tags: [], subcategory: "Dev Tools"),
            entry("battery", category: "System", tags: [], subcategory: "Monitoring"),
            entry("paste", category: "Clipboard", tags: []),
        ]
        let result = filterCatalog(
            entries: entries, category: "System", subcategory: "Dev Tools", tags: [], search: ""
        )
        XCTAssertEqual(result.map(\.id), ["ports"])
    }

    func testCategoryWithoutSubcategoryReturnsAllMembers() {
        let entries = [
            entry("ports", category: "System", tags: [], subcategory: "Dev Tools"),
            entry("battery", category: "System", tags: [], subcategory: "Monitoring"),
        ]
        let result = filterCatalog(entries: entries, category: "System", subcategory: nil, tags: [], search: "")
        XCTAssertEqual(Set(result.map(\.id)), ["ports", "battery"])
    }

    func testSidebarSelectionExposesCategoryAndSubcategory() {
        XCTAssertNil(CatalogSidebarSelection.all.category)
        XCTAssertNil(CatalogSidebarSelection.all.subcategory)
        XCTAssertEqual(CatalogSidebarSelection.category("System").category, "System")
        XCTAssertNil(CatalogSidebarSelection.category("System").subcategory)
        let drilled = CatalogSidebarSelection.subcategory(category: "System", name: "Dev Tools")
        XCTAssertEqual(drilled.category, "System")
        XCTAssertEqual(drilled.subcategory, "Dev Tools")
    }
}
