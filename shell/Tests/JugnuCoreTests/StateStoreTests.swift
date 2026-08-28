@testable import JugnuCore
import XCTest

final class StateStoreTests: XCTestCase {
    func testMissingFileDecodesEmptyRecentAndFavorites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = try StateStore(paths: JugnuPaths(home: dir)).load()
        XCTAssertEqual(state.recentCommandIDs, [])
        XCTAssertEqual(state.favoriteCommandIDs, [])
        XCTAssertFalse(state.firstRunCompleted)
    }

    func testRecordRecentMovesToFrontAndCaps() {
        var state = JugnuState()
        state.recordRecent(qualifiedId: "a.toggle")
        state.recordRecent(qualifiedId: "b.toggle")
        state.recordRecent(qualifiedId: "a.toggle")
        XCTAssertEqual(state.recentCommandIDs, ["a.toggle", "b.toggle"])

        for i in 0 ..< 10 {
            state.recordRecent(qualifiedId: "c\(i).x")
        }
        XCTAssertEqual(state.recentCommandIDs.count, 8)
        XCTAssertEqual(state.recentCommandIDs.first, "c9.x")
    }

    func testToggleFavoriteAddsAndRemoves() {
        var state = JugnuState()
        state.toggleFavorite(qualifiedId: "mic-mute.toggle")
        XCTAssertEqual(state.favoriteCommandIDs, ["mic-mute.toggle"])
        state.toggleFavorite(qualifiedId: "mic-mute.toggle")
        XCTAssertEqual(state.favoriteCommandIDs, [])
    }

    func test_moveFavorite_reordersInPlace() {
        var state = JugnuState(favoriteCommandIDs: ["a", "b", "c"])
        state.moveFavorite(from: 0, to: 2)
        XCTAssertEqual(state.favoriteCommandIDs, ["b", "c", "a"])
    }

    func test_moveFavorite_outOfBounds_isNoOp() {
        var state = JugnuState(favoriteCommandIDs: ["a", "b"])
        state.moveFavorite(from: 0, to: 5)
        XCTAssertEqual(state.favoriteCommandIDs, ["a", "b"])
        state.moveFavorite(from: 9, to: 0)
        XCTAssertEqual(state.favoriteCommandIDs, ["a", "b"])
    }

    func test_removeFavorite_removesMatchingID() {
        var state = JugnuState(favoriteCommandIDs: ["a", "b", "c"])
        state.removeFavorite(qualifiedId: "b")
        XCTAssertEqual(state.favoriteCommandIDs, ["a", "c"])
    }

    func test_removeFavorite_missingID_isNoOp() {
        var state = JugnuState(favoriteCommandIDs: ["a"])
        state.removeFavorite(qualifiedId: "not-there")
        XCTAssertEqual(state.favoriteCommandIDs, ["a"])
    }
}
