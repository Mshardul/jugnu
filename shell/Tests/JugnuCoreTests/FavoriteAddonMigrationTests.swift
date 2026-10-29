@testable import JugnuCore
import XCTest

final class FavoriteAddonMigrationTests: XCTestCase {
    func test_migration_keepsFirstAddonDropsUnresolvedAndDedupes() {
        let owners = [
            "jugnu.audio.mute": "jugnu.audio",
            "jugnu.audio.volume": "jugnu.audio",
            "jugnu.clipboard.copy": "jugnu.clipboard"
        ]
        let migrated = migrateFavoriteAddons(
            commandIDs: [
                "jugnu.audio.mute",
                "missing.command",
                "jugnu.clipboard.copy",
                "jugnu.audio.volume"
            ],
            owner: { owners[$0] }
        )
        XCTAssertEqual(migrated, ["jugnu.audio", "jugnu.clipboard"])
    }

    func test_migration_runsOnce() {
        var state = JugnuState(favoriteCommandIDs: ["jugnu.audio.mute"])
        state.migrateFavoriteAddons { _ in "jugnu.audio" }
        state.favoriteCommandIDs.append("jugnu.clipboard.copy")
        state.migrateFavoriteAddons { _ in "jugnu.clipboard" }
        XCTAssertEqual(state.favoriteAddonIDs, ["jugnu.audio"])
        XCTAssertTrue(state.favoriteAddonsMigrated)
    }

    func test_oldStateJSON_staysParseable() throws {
        let json = """
        {"firstRunCompleted":true,"recentCommandIDs":["a.b"],"favoriteCommandIDs":["jugnu.audio.mute"]}
        """
        let state = try JSONDecoder().decode(JugnuState.self, from: Data(json.utf8))
        XCTAssertEqual(state.favoriteCommandIDs, ["jugnu.audio.mute"])
        XCTAssertEqual(state.recentCommandIDs, ["a.b"])
        XCTAssertEqual(state.favoriteAddonIDs, [])
        XCTAssertFalse(state.favoriteAddonsMigrated)
        XCTAssertTrue(state.firstRunCompleted)
    }
}
