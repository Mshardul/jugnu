@testable import JugnuCore
import XCTest

final class FirstRunPermissionsTests: XCTestCase {
    func testExpandUnionsSelectedOnly() {
        let entries = [
            entry(id: "a", name: "Clip", permissions: [.clipboard]),
            entry(id: "b", name: "Weather", permissions: [.network]),
            entry(id: "c", name: "Layouts", permissions: [.accessibility, .clipboard])
        ]
        let expand = FirstRunPermissions.expand(entries: entries, selectedIDs: ["a", "c"])
        XCTAssertEqual(expand.map(\.permission), [.accessibility, .clipboard])
        XCTAssertEqual(expand[0].addonNames, ["Layouts"])
        XCTAssertEqual(expand[1].addonNames, ["Clip", "Layouts"])
    }

    func testExpandEmptyWhenNoPermissions() {
        let entries = [entry(id: "a", name: "Plain", permissions: [])]
        XCTAssertTrue(FirstRunPermissions.expand(entries: entries, selectedIDs: ["a"]).isEmpty)
    }

    private func entry(id: String, name: String, permissions: [AddonPermission]) -> RegistryEntry {
        RegistryEntry(
            id: id,
            name: name,
            version: "1.0.0",
            api: 1,
            url: "https://example.com/\(id).zip",
            sha256: String(repeating: "a", count: 64),
            summary: "",
            category: "Tools",
            permissions: permissions
        )
    }
}
