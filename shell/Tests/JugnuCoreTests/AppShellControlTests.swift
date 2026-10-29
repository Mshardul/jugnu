@testable import JugnuCore
import XCTest

final class AppShellControlTests: XCTestCase {
    func test_hiddenInvoke_opensAFreshHome() {
        let session = applyAppShellControl(.invokeHotkey, to: .hidden)
        XCTAssertEqual(session, .visible(.freshHome()))
    }

    func test_hiddenDismissals_doNothing() {
        for control in [AppShellControl.escape, .clickOutside, .commandW] {
            XCTAssertEqual(applyAppShellControl(control, to: .hidden), .hidden)
        }
    }

    func test_controlMatrix() {
        let cases: [(AppShellPage, AppShellControl, AppShellControlEffect)] = [
            (.home, .invokeHotkey, .hideAndClearRouteStack),
            (.home, .escape, .hideAndClearRouteStack),
            (.home, .clickOutside, .ignore),
            (.home, .commandW, .hideAndClearRouteStack),
            (.search, .invokeHotkey, .closeSearchRestoreHome),
            (.search, .escape, .closeSearchRestoreHome),
            (.search, .clickOutside, .ignore),
            (.search, .commandW, .closeSearchRestoreHome),
            (.search, .searchBackdrop, .closeSearchRestoreHome),
            (.editHome, .invokeHotkey, .exitEditHome),
            (.editHome, .escape, .exitEditHome),
            (.editHome, .clickOutside, .ignore),
            (.editHome, .commandW, .exitEditHome),
            (.catalog, .invokeHotkey, .goHome),
            (.catalog, .escape, .popDetailOrGoHome),
            (.catalog, .clickOutside, .ignore),
            (.catalog, .commandW, .popDetailOrGoHome),
            (.preferences, .invokeHotkey, .goHome),
            (.preferences, .escape, .goHome),
            (.preferences, .clickOutside, .ignore),
            (.preferences, .commandW, .goHome),
            (.focusedAddon, .invokeHotkey, .goHome),
            (.focusedAddon, .escape, .popFocusedAddon),
            (.focusedAddon, .clickOutside, .followCommandDismissPolicy),
            (.focusedAddon, .commandW, .popFocusedAddon)
        ]
        for (page, control, effect) in cases {
            XCTAssertEqual(
                appShellControlEffect(page: page, control: control),
                effect,
                "\(page) + \(control)"
            )
        }
    }

    func test_closeSearch_keepsHomeScrollAndDropsTheQuery() {
        var navigation = AppNavigation.freshHome()
        navigation.page = .search
        navigation.homeScroll = 240
        navigation.searchQuery = "mute"
        let session = applyAppShellControl(.escape, to: .visible(navigation))
        guard case let .visible(next) = session else {
            return XCTFail("expected home")
        }
        XCTAssertEqual(next.page, .home)
        XCTAssertEqual(next.homeScroll, 240)
        XCTAssertEqual(next.searchQuery, "")
    }

    func test_exitEditHome_keepsScroll() {
        var navigation = AppNavigation.freshHome()
        navigation.page = .editHome
        navigation.isEditingHome = true
        navigation.homeScroll = 80
        let session = applyAppShellControl(.commandW, to: .visible(navigation))
        guard case let .visible(next) = session else {
            return XCTFail("expected home")
        }
        XCTAssertEqual(next.page, .home)
        XCTAssertFalse(next.isEditingHome)
        XCTAssertEqual(next.homeScroll, 80)
    }

    func test_escapeOnCatalogDetail_restoresTheCatalogSnapshot() {
        var navigation = AppNavigation.freshHome()
        navigation.page = .catalog
        navigation.catalog = CatalogNavigation(
            section: .category("Audio", subcategory: "Output"),
            query: "vol",
            filters: ["installed"],
            scroll: 120,
            selectedCardID: "jugnu.audio",
            detail: AddonDetailRoute(addonID: "jugnu.audio", section: .actions)
        )
        let session = applyAppShellControl(.escape, to: .visible(navigation))
        guard case let .visible(next) = session else {
            return XCTFail("expected catalog")
        }
        XCTAssertEqual(next.page, .catalog)
        XCTAssertNil(next.catalog.detail)
        XCTAssertEqual(next.catalog.section, .category("Audio", subcategory: "Output"))
        XCTAssertEqual(next.catalog.query, "vol")
        XCTAssertEqual(next.catalog.filters, ["installed"])
        XCTAssertEqual(next.catalog.scroll, 120)
        XCTAssertEqual(next.catalog.selectedCardID, "jugnu.audio")
    }

    func test_escapeOnCatalog_goesHomeAndKeepsTheCatalogSnapshot() {
        var navigation = AppNavigation.freshHome()
        navigation.page = .catalog
        navigation.homeScroll = 16
        navigation.catalog.query = "clock"
        let session = applyAppShellControl(.escape, to: .visible(navigation))
        guard case let .visible(next) = session else {
            return XCTFail("expected home")
        }
        XCTAssertEqual(next.page, .home)
        XCTAssertEqual(next.homeScroll, 16)
        XCTAssertEqual(next.catalog.query, "clock")
    }

    func test_escapeOnFocusedAddon_returnsToTheOriginatingCatalogDetail() {
        var navigation = AppNavigation.freshHome()
        navigation.page = .focusedAddon
        navigation.focusedOrigin = .catalog
        navigation.catalog.detail = AddonDetailRoute(addonID: "jugnu.audio", section: .settings)
        let session = applyAppShellControl(.escape, to: .visible(navigation))
        guard case let .visible(next) = session else {
            return XCTFail("expected catalog")
        }
        XCTAssertEqual(next.page, .catalog)
        XCTAssertEqual(next.catalog.detail?.section, .settings)
    }

    func test_clickOutsideFocusedAddon_doesNotChangeTheRoute() {
        var navigation = AppNavigation.freshHome()
        navigation.page = .focusedAddon
        navigation.focusedOrigin = .home
        XCTAssertEqual(
            applyAppShellControl(.clickOutside, to: .visible(navigation)),
            .visible(navigation)
        )
    }

    func test_homeEscape_hides() {
        XCTAssertEqual(applyAppShellControl(.escape, to: .visible(.freshHome())), .hidden)
    }
}
