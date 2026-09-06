@testable import Jugnu
import JugnuCore
import XCTest

@MainActor
final class FirstRunKeepCurrentTests: XCTestCase {
    func testCompleteFirstRunWritesKeepFlagsAndSkipsInstalls() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(paths: JugnuPaths(home: home), loadAddons: false)
        try await model.completeFirstRun(
            keepAppCurrent: false,
            keepAddonsCurrent: false,
            useCommandSpace: true,
            selectedAddonIDs: [],
            localAddonRoots: []
        )
        let loaded = try ConfigStore(paths: JugnuPaths(home: home)).load()
        XCTAssertFalse(loaded.shell.keepAppCurrent)
        XCTAssertFalse(loaded.shell.keepAddonsCurrent)
        XCTAssertEqual(loaded.shell.hotkey, "cmd+space")
        XCTAssertTrue(model.state.firstRunCompleted)
        XCTAssertTrue(model.installedAddonIDs().isEmpty)
    }

    func testCloseOnPageOneKeepsBothOnAndInstallsNothing() {
        let session = FirstRunSession()
        session.keepAppCurrent = false
        session.keepAddonsCurrent = false
        session.useCommandSpace = true
        let outcome = session.closeOutcome()
        XCTAssertTrue(outcome.keepApp)
        XCTAssertTrue(outcome.keepAddons)
        XCTAssertFalse(outcome.cmdSpace)
        XCTAssertTrue(outcome.ids.isEmpty)
    }

    func testCloseOnPageTwoUsesStepOneFlagsAndEmptySelection() {
        let session = FirstRunSession()
        session.page = 2
        session.keepAppCurrent = false
        session.keepAddonsCurrent = true
        session.useCommandSpace = false
        session.selectedIDs = ["jugnu.mic-mute"]
        let outcome = session.closeOutcome()
        XCTAssertFalse(outcome.keepApp)
        XCTAssertTrue(outcome.keepAddons)
        XCTAssertTrue(outcome.ids.isEmpty)
    }
}
