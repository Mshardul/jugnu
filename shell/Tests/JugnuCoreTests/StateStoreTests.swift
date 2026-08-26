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
}
