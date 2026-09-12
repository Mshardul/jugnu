@testable import JugnuCore
import XCTest

final class PermissionsSetTests: XCTestCase {
    func testParseKnownIds() throws {
        let parsed = try PermissionsSet.parse(["clipboard", "accessibility", "clipboard"])
        XCTAssertEqual(parsed, [.accessibility, .clipboard])
    }

    func testParseUnknownThrows() {
        XCTAssertThrowsError(try PermissionsSet.parse(["clipboard", "telepathy"])) { err in
            XCTAssertEqual(err as? PermissionsParseError, .unknown("telepathy"))
        }
    }

    func testGrewOnlyNewIds() throws {
        let old = try PermissionsSet.parse(["clipboard"])
        let new = try PermissionsSet.parse(["clipboard", "accessibility"])
        XCTAssertEqual(PermissionsSet.grew(from: old, to: new), [.accessibility])
    }

    func testGrewFromEmptyIsAllNew() throws {
        let new = try PermissionsSet.parse(["network", "clipboard"])
        XCTAssertEqual(PermissionsSet.grew(from: [], to: new), [.network, .clipboard])
    }

    func testNeedsLine() throws {
        XCTAssertNil(PermissionsSet.needsLine([]))
        let line = try PermissionsSet.needsLine(PermissionsSet.parse(["clipboard", "accessibility"]))
        XCTAssertEqual(line, "Needs Accessibility, Clipboard")
    }

    func testUnionExpandGroupsNames() {
        let rows = PermissionsSet.unionExpand(addons: [
            (name: "Clip Tools", permissions: [.clipboard]),
            (name: "Weather", permissions: [.network]),
            (name: "History", permissions: [.clipboard, .background])
        ])
        XCTAssertEqual(rows.map(\.permission), [.network, .clipboard, .background])
        XCTAssertEqual(rows.first { $0.permission == .clipboard }?.addonNames, ["Clip Tools", "History"])
        XCTAssertEqual(rows.first { $0.permission == .network }?.addonNames, ["Weather"])
        XCTAssertEqual(rows.first { $0.permission == .background }?.addonNames, ["History"])
    }

    func testDisplayTitlesAndReasons() {
        XCTAssertEqual(AddonPermission.accessibility.displayTitle, "Accessibility")
        XCTAssertEqual(AddonPermission.background.displayTitle, "Background agent")
        XCTAssertTrue(AddonPermission.accessibility.isTCC)
        XCTAssertFalse(AddonPermission.clipboard.isTCC)
        XCTAssertFalse(AddonPermission.accessibility.reason.isEmpty)
    }
}
