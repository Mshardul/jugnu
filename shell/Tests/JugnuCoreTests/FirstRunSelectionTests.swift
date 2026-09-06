@testable import JugnuCore
import XCTest

final class FirstRunSelectionTests: XCTestCase {
    func testPrechecksRecommendedTag() {
        let entries = [
            entry("plain", tags: []),
            entry("star", tags: ["recommended"]),
            entry("also", tags: ["recommended", "popup-ui"]),
        ]
        XCTAssertEqual(
            FirstRunSelection.precheckedIDs(entries: entries, fallback: ["plain"]),
            ["star", "also"]
        )
    }

    func testFallsBackWhenNoRecommendedTag() {
        let entries = [entry("jugnu.mic-mute", tags: []), entry("other", tags: [])]
        XCTAssertEqual(
            FirstRunSelection.precheckedIDs(
                entries: entries,
                fallback: ["jugnu.mic-mute", "jugnu.ports"]
            ),
            ["jugnu.mic-mute"]
        )
    }

    func testEmptyCatalogYieldsNoPrecheck() {
        XCTAssertEqual(
            FirstRunSelection.precheckedIDs(entries: [], fallback: ["jugnu.mic-mute"]),
            []
        )
    }
}

private func entry(_ id: String, tags: [String]) -> RegistryEntry {
    RegistryEntry(
        id: id, name: id, version: "1.0.0", api: 1, url: "https://x/\(id).zip", sha256: "x",
        summary: "", category: "System", tags: tags
    )
}
