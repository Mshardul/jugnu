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

    func testCatalogCardAction_followsInstallUpdateEnableOpen() {
        XCTAssertEqual(
            AddonPrimaryAction.catalogCardAction(
                isInstalled: false, isEnabled: false, updateAvailable: false, primary: nil
            ),
            .install
        )
        XCTAssertEqual(
            AddonPrimaryAction.catalogCardAction(
                isInstalled: true, isEnabled: false, updateAvailable: true, primary: "open"
            ),
            .update
        )
        XCTAssertEqual(
            AddonPrimaryAction.catalogCardAction(
                isInstalled: true, isEnabled: false, updateAvailable: false, primary: "open"
            ),
            .enable
        )
        XCTAssertEqual(
            AddonPrimaryAction.catalogCardAction(
                isInstalled: true, isEnabled: true, updateAvailable: false, primary: "open"
            ),
            .open
        )
        XCTAssertNil(
            AddonPrimaryAction.catalogCardAction(
                isInstalled: true, isEnabled: true, updateAvailable: false, primary: nil
            )
        )
    }
}
