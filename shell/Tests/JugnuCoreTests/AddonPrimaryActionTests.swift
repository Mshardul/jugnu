import JugnuCore
import XCTest

final class AddonPrimaryActionTests: XCTestCase {
    func testShowsOpenWhenInstalledEnabledWithPrimary() {
        XCTAssertTrue(AddonPrimaryAction.shouldShowOpen(isInstalled: true, isEnabled: true, primary: "open"))
    }

    func testHidesOpenWhenNoPrimary() {
        XCTAssertFalse(AddonPrimaryAction.shouldShowOpen(isInstalled: true, isEnabled: true, primary: nil))
    }

    func testHidesOpenWhenNotInstalled() {
        XCTAssertFalse(AddonPrimaryAction.shouldShowOpen(isInstalled: false, isEnabled: true, primary: "open"))
    }

    func testHidesOpenWhenDisabled() {
        XCTAssertFalse(AddonPrimaryAction.shouldShowOpen(isInstalled: true, isEnabled: false, primary: "open"))
    }
}
