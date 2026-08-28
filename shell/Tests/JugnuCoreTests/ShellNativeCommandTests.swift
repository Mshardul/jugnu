@testable import JugnuCore
import XCTest

final class ShellNativeCommandTests: XCTestCase {
    func testAllShipsBrowseAndPreferences() {
        XCTAssertEqual(ShellNativeCommand.all.map(\.id), ["browse-addons", "preferences"])
    }

    func testVisibleDropsHiddenIDs() {
        XCTAssertEqual(
            ShellNativeCommand.visible(hidden: ["browse-addons"]).map(\.id),
            ["preferences"]
        )
        XCTAssertTrue(ShellNativeCommand.visible(hidden: ["browse-addons", "preferences"]).isEmpty)
        XCTAssertEqual(ShellNativeCommand.visible(hidden: []).count, 2)
    }

    func testMatchScoreZeroForEmptyOrNonMatchingQuery() {
        let browse = ShellNativeCommand.all[0]
        XCTAssertEqual(browse.matchScore(query: ""), 0)
        XCTAssertEqual(browse.matchScore(query: "   "), 0)
        XCTAssertEqual(browse.matchScore(query: "xylophone"), 0)
    }

    func testMatchScoreMatchesTitleAndKeywords() {
        let prefs = ShellNativeCommand.all[1]
        XCTAssertGreaterThan(prefs.matchScore(query: "pref"), 0)
        XCTAssertGreaterThan(prefs.matchScore(query: "settings"), 0)
        XCTAssertGreaterThan(prefs.matchScore(query: "theme"), 0)
    }
}
