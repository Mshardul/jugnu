@testable import JugnuUI
import XCTest

final class FavoritesRowLogicTests: XCTestCase {
    func test_fiveOrFewer_showsAllNoMoreIndicator() {
        let result = favoritesSlots(from: ["a", "b", "c"], limit: 5)
        XCTAssertEqual(result.shown, ["a", "b", "c"])
        XCTAssertFalse(result.hasMore)
    }

    func test_exactlyFive_noMoreIndicator() {
        let result = favoritesSlots(from: ["a", "b", "c", "d", "e"], limit: 5)
        XCTAssertEqual(result.shown, ["a", "b", "c", "d", "e"])
        XCTAssertFalse(result.hasMore)
    }

    func test_moreThanFive_showsTop5PlusMoreIndicator() {
        let result = favoritesSlots(from: ["a", "b", "c", "d", "e", "f", "g"], limit: 5)
        XCTAssertEqual(result.shown, ["a", "b", "c", "d", "e"])
        XCTAssertTrue(result.hasMore)
    }

    func test_empty_showsNothingNoMoreIndicator() {
        let result = favoritesSlots(from: [String](), limit: 5)
        XCTAssertEqual(result.shown, [])
        XCTAssertFalse(result.hasMore)
    }
}
