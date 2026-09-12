@testable import JugnuCore
import XCTest

final class AddonBulkUpdateTests: XCTestCase {
    func testNoneWhenCatalogMatchesInstalled() {
        let catalog = [entry("a", version: "1.0.0"), entry("b", version: "2.0.0")]
        let installed = ["a": "1.0.0", "b": "2.0.0"]
        XCTAssertTrue(AddonBulkUpdate.outdated(installed: installed, catalog: catalog).isEmpty)
    }

    func testOneOutdatedPreservesCatalogOrder() {
        let catalog = [
            entry("keep", version: "1.0.0"),
            entry("old", version: "1.1.0"),
            entry("also-old", version: "3.0.0")
        ]
        let installed = ["keep": "1.0.0", "old": "1.0.0", "also-old": "2.0.0"]
        XCTAssertEqual(
            AddonBulkUpdate.outdated(installed: installed, catalog: catalog).map(\.id),
            ["old", "also-old"]
        )
    }

    func testMixedAndUninstalledAreSkipped() {
        let catalog = [
            entry("fresh", version: "1.0.0"),
            entry("stale", version: "2.0.0")
        ]
        let installed = ["stale": "1.0.0"]
        XCTAssertEqual(
            AddonBulkUpdate.outdated(installed: installed, catalog: catalog).map(\.id),
            ["stale"]
        )
    }

    func testInvalidVersionsAreSkipped() {
        let catalog = [
            entry("bad-installed", version: "1.0.1"),
            entry("bad-registry", version: "not-semver"),
            entry("ok", version: "1.0.1")
        ]
        let installed = [
            "bad-installed": "nope",
            "bad-registry": "1.0.0",
            "ok": "1.0.0"
        ]
        XCTAssertEqual(
            AddonBulkUpdate.outdated(installed: installed, catalog: catalog).map(\.id),
            ["ok"]
        )
    }
}

private func entry(_ id: String, version: String) -> RegistryEntry {
    RegistryEntry(
        id: id, name: id, version: version, api: 1, url: "https://x/\(id).zip", sha256: "x",
        summary: "", category: "System"
    )
}
