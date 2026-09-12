import JugnuCore
import XCTest

final class PrefsPaneTitleTests: XCTestCase {
    func testPaneTitle() {
        XCTAssertEqual(PrefsPaneTitle.title(for: .theme), "Theme")
        XCTAssertEqual(PrefsPaneTitle.title(for: .addonsInstalled), "Installed")
        XCTAssertEqual(PrefsPaneTitle.title(for: .addonsUpdates), "Updates")
        XCTAssertEqual(PrefsPaneTitle.title(for: .general), "General")
    }
}
