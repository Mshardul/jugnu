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
}
