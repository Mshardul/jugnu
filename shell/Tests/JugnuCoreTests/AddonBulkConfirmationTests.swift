@testable import JugnuCore
import XCTest

final class AddonBulkConfirmationTests: XCTestCase {
    func testConfirmAddonBulkUICopy() {
        let ui = confirmAddonBulkUI(count: 3)
        XCTAssertEqual(ui.pattern, .confirm)
        XCTAssertEqual(ui.title, "Update addons?")
        XCTAssertEqual(ui.message, "3 addons have updates. Update all?")
        XCTAssertEqual(ui.confirmLabel, "Update")
        XCTAssertEqual(ui.cancelLabel, "Later")
    }
}
