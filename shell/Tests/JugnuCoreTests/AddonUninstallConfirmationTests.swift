import XCTest
@testable import JugnuCore

final class AddonUninstallConfirmationTests: XCTestCase {
    func testConfirmUninstallUIBuildsExpectedCopy() {
        let ui = confirmUninstallUI(name: "Clipboard History")
        XCTAssertEqual(ui.pattern, .confirm)
        XCTAssertEqual(ui.title, "Uninstall Clipboard History?")
        XCTAssertEqual(ui.message, "This removes it and any local data it stored.")
        XCTAssertEqual(ui.confirmLabel, "Uninstall")
        XCTAssertEqual(ui.cancelLabel, "Cancel")
    }
}
