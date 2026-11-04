@testable import JugnuCore
import XCTest

final class HostedBlockTests: XCTestCase {
    func testResolvesOnlyFirstPartyShellCommands() {
        XCTAssertEqual(HostedBlock.resolve(addonID: "jugnu.convert", commandID: "convert-file"), .convertFile)
        XCTAssertEqual(HostedBlock.resolve(addonID: "jugnu.convert", commandID: "convert-text"), .convertText)
        XCTAssertNil(HostedBlock.resolve(addonID: "jugnu.convert", commandID: "other"))
        XCTAssertNil(HostedBlock.resolve(addonID: "acme.convert", commandID: "convert-file"))
    }

    func testOpeningFromCatalogReturnsToCatalog() {
        var nav = AppNavigation(page: .catalog)
        nav.catalog.query = "pdf"
        let open = nav.openingBlock(.convertText)
        XCTAssertEqual(open.page, .focusedAddon)
        XCTAssertEqual(open.block, .convertText)
        XCTAssertEqual(open.focusedOrigin, .catalog)

        guard case let .visible(back) = applyAppShellControl(.escape, to: .visible(open)) else {
            return XCTFail("expected visible")
        }
        XCTAssertEqual(back.page, .catalog)
        XCTAssertNil(back.block)
        XCTAssertNil(back.focusedOrigin)
        XCTAssertEqual(back.catalog.query, "pdf")
    }

    func testOpeningFromSearchReturnsToHome() {
        let nav = AppNavigation(page: .search, searchQuery: "conv")
        let open = nav.openingBlock(.convertFile)
        XCTAssertEqual(open.focusedOrigin, .home)
        XCTAssertEqual(open.searchQuery, "")
        guard case let .visible(back) = applyAppShellControl(.commandW, to: .visible(open)) else {
            return XCTFail("expected visible")
        }
        XCTAssertEqual(back.page, .home)
        XCTAssertNil(back.block)
    }

    func testReopeningWhileFocusedKeepsOriginalOrigin() {
        let open = AppNavigation(page: .catalog).openingBlock(.convertFile)
        let switched = open.openingBlock(.convertText)
        XCTAssertEqual(switched.focusedOrigin, .catalog)
        XCTAssertEqual(switched.block, .convertText)
    }

    func testHotkeyFromBlockGoesHomeAndClearsBlock() {
        let open = AppNavigation(page: .preferences).openingBlock(.convertFile)
        guard case let .visible(home) = applyAppShellControl(.invokeHotkey, to: .visible(open)) else {
            return XCTFail("expected visible")
        }
        XCTAssertEqual(home.page, .home)
        XCTAssertNil(home.block)
        XCTAssertNil(home.focusedOrigin)
    }

    func testClickOutsideDoesNotCloseBlock() {
        let open = AppNavigation().openingBlock(.convertText)
        XCTAssertEqual(applyAppShellControl(.clickOutside, to: .visible(open)), .visible(open))
    }
}
