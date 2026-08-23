import XCTest
@testable import JugnuCore

final class RegistryClientTests: XCTestCase {
    private let baseJSON = """
    {
      "id": "widget", "name": "Widget", "version": "1.0.0", "api": 1,
      "url": "https://example.com/widget.zip", "sha256": "abc",
      "summary": "A widget"
    }
    """

    func testDecodesWithoutNewFieldsUsingDefaults() throws {
        let patched = baseJSON.replacingOccurrences(
            of: "\"summary\": \"A widget\"",
            with: "\"summary\": \"A widget\", \"category\": \"System\""
        )
        let data = Data(("[" + patched + "]").utf8)
        let entries = try JSONDecoder().decode([RegistryEntry].self, from: data)
        XCTAssertEqual(entries[0].category, "System")
        XCTAssertNil(entries[0].subcategory)
        XCTAssertEqual(entries[0].tags, [])
        XCTAssertNil(entries[0].description)
        XCTAssertEqual(entries[0].commands, [])
    }

    func testMissingCategoryFailsDecode() {
        let data = Data(("[" + baseJSON + "]").utf8)
        XCTAssertThrowsError(try JSONDecoder().decode([RegistryEntry].self, from: data))
    }

    func testDecodesFullEntryWithCommandsAndTags() throws {
        let json = """
        [{
          "id": "ports", "name": "Ports", "version": "1.0.0", "api": 1,
          "url": "https://example.com/ports.zip", "sha256": "abc",
          "summary": "List listening ports",
          "category": "System", "subcategory": "Dev Tools",
          "tags": ["popup-ui", "dev-tool", "recommended"],
          "description": "Lists listening ports and lets you kill by pid.",
          "commands": [{"id": "list", "title": "List ports", "subtitle": "Show listening ports"}]
        }]
        """
        let entries = try JSONDecoder().decode([RegistryEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries[0].subcategory, "Dev Tools")
        XCTAssertEqual(entries[0].tags, ["popup-ui", "dev-tool", "recommended"])
        XCTAssertEqual(entries[0].description, "Lists listening ports and lets you kill by pid.")
        XCTAssertEqual(entries[0].commands, [RegistryCommand(id: "list", title: "List ports", subtitle: "Show listening ports")])
    }
}
