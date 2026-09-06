@testable import JugnuCore
import XCTest

final class AppUpdateConfirmationTests: XCTestCase {
    func testConfirmAppUpdateUIWithoutNotes() {
        let ui = confirmAppUpdateUI(version: "0.2.0", notes: nil)
        XCTAssertEqual(ui.pattern, .confirm)
        XCTAssertEqual(ui.title, "Update Jugnu?")
        XCTAssertEqual(ui.message, "Jugnu 0.2.0 is ready. Update and restart?")
        XCTAssertEqual(ui.confirmLabel, "Update and Restart")
        XCTAssertEqual(ui.cancelLabel, "Later")
    }

    func testConfirmAppUpdateUIIncludesNotes() {
        let ui = confirmAppUpdateUI(version: "0.2.0", notes: "Faster search.")
        XCTAssertEqual(
            ui.message,
            "Jugnu 0.2.0 is ready. Update and restart?\n\nFaster search."
        )
    }
}
