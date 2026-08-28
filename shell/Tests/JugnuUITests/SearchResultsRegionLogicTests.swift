@testable import JugnuUI
import XCTest

final class SearchResultsRegionLogicTests: XCTestCase {
    func test_zeroResults_noRows_noLink_noScroll() {
        let layout = resultSlots(results: [String](), slotCount: 5)
        XCTAssertEqual(layout.rows, [])
        XCTAssertNil(layout.showAllLinkSlot)
        XCTAssertFalse(layout.scrolls)
    }

    func test_oneResult_linkAtSlot5_noScroll() {
        let layout = resultSlots(results: ["a"], slotCount: 5)
        XCTAssertEqual(layout.rows, ["a"])
        XCTAssertEqual(layout.showAllLinkSlot, 5)
        XCTAssertFalse(layout.scrolls)
    }

    func test_fourResults_linkAtSlot5_noScroll() {
        let layout = resultSlots(results: ["a", "b", "c", "d"], slotCount: 5)
        XCTAssertEqual(layout.rows, ["a", "b", "c", "d"])
        XCTAssertEqual(layout.showAllLinkSlot, 5)
        XCTAssertFalse(layout.scrolls)
    }

    func test_fiveResults_noLink_scrolls() {
        let layout = resultSlots(results: ["a", "b", "c", "d", "e"], slotCount: 5)
        XCTAssertEqual(layout.rows, ["a", "b", "c", "d", "e"])
        XCTAssertNil(layout.showAllLinkSlot, "more than 4 real results means no room for the link")
        XCTAssertTrue(layout.scrolls)
    }

    func test_twentyResults_noLink_scrolls() {
        let layout = resultSlots(results: Array(1 ... 20).map(String.init), slotCount: 5)
        XCTAssertEqual(layout.rows.count, 20)
        XCTAssertNil(layout.showAllLinkSlot)
        XCTAssertTrue(layout.scrolls)
    }

    func test_launcherSelection_addonSegmentFirst() {
        XCTAssertEqual(LauncherSelection.resolve(index: 0, addonCount: 3, shellNativeCount: 2), .addon(0))
        XCTAssertEqual(LauncherSelection.resolve(index: 2, addonCount: 3, shellNativeCount: 2), .addon(2))
    }

    func test_launcherSelection_shellNativeSegmentAfterAddons() {
        XCTAssertEqual(LauncherSelection.resolve(index: 3, addonCount: 3, shellNativeCount: 2), .shellNative(0))
        XCTAssertEqual(LauncherSelection.resolve(index: 4, addonCount: 3, shellNativeCount: 2), .shellNative(1))
    }

    func test_launcherSelection_outOfRangeIsNone() {
        XCTAssertEqual(LauncherSelection.resolve(index: 5, addonCount: 3, shellNativeCount: 2), .none)
        XCTAssertEqual(LauncherSelection.resolve(index: -1, addonCount: 3, shellNativeCount: 2), .none)
        XCTAssertEqual(LauncherSelection.resolve(index: 0, addonCount: 0, shellNativeCount: 0), .none)
    }

    func test_launcherSelection_shellNativeOnlyWhenNoAddons() {
        XCTAssertEqual(LauncherSelection.resolve(index: 0, addonCount: 0, shellNativeCount: 2), .shellNative(0))
        XCTAssertEqual(LauncherSelection.resolve(index: 1, addonCount: 0, shellNativeCount: 2), .shellNative(1))
    }
}
