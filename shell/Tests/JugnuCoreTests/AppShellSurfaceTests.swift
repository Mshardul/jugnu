import CoreGraphics
@testable import JugnuCore
import XCTest

final class AppShellSurfaceTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 80, width: 1440, height: 900)

    func test_present_usesTheInsetFrameAndAFreshHome() {
        let surface = presentAppShell(in: visible)
        XCTAssertEqual(surface.frame, appShellFrame(in: visible))
        XCTAssertEqual(surface.navigation, .freshHome())
    }

    func test_catalogAndPreferences_swapOnTheSameFrame() {
        let home = presentAppShell(in: visible)
        let catalog = showAppShellPage(.catalog, on: home)
        let preferences = showAppShellPage(.preferences, on: catalog)
        let back = showAppShellPage(.home, on: preferences)

        XCTAssertEqual(catalog.frame, home.frame)
        XCTAssertEqual(preferences.frame, home.frame)
        XCTAssertEqual(back.frame, home.frame)
        XCTAssertEqual(catalog.navigation.page, .catalog)
        XCTAssertEqual(preferences.navigation.page, .preferences)
        XCTAssertEqual(back.navigation.page, .home)
    }

    func test_search_opensOverHomeWithoutANewFrame() {
        var home = presentAppShell(in: visible)
        home.navigation.homeScroll = 48
        let search = openAppShellSearch(on: home, query: "m")

        XCTAssertEqual(search.frame, home.frame)
        XCTAssertEqual(search.navigation.page, .search)
        XCTAssertEqual(search.navigation.searchQuery, "m")
        XCTAssertEqual(search.navigation.homeScroll, 48)
    }

    func test_runningASearchAction_restoresHomeOnTheSameFrame() {
        let home = presentAppShell(in: visible)
        let search = openAppShellSearch(on: home, query: "mute")
        let action = AppShellSearchAction(
            addonName: "Audio",
            actionTitle: "Mute microphone",
            qualifiedID: "jugnu.audio.mute"
        )

        let activation = activateAppShellSearch(.action(action), on: search)

        XCTAssertEqual(activation.qualifiedID, "jugnu.audio.mute")
        XCTAssertEqual(activation.surface.frame, home.frame)
        XCTAssertEqual(activation.surface.navigation.page, .home)
        XCTAssertEqual(activation.surface.navigation.searchQuery, "")
        XCTAssertEqual(
            appShellSearchLabel(addonName: "Audio", actionTitle: "Mute microphone"),
            "Audio › Mute microphone"
        )
    }

    func test_searchDestination_opensThatPageOnTheSameFrame() {
        let search = openAppShellSearch(on: presentAppShell(in: visible), query: "catalog")
        let activation = activateAppShellSearch(
            .page(.catalog, title: "Catalog"),
            on: search
        )
        XCTAssertNil(activation.qualifiedID)
        XCTAssertEqual(activation.surface.frame, search.frame)
        XCTAssertEqual(activation.surface.navigation.page, .catalog)
        XCTAssertEqual(activation.surface.navigation.searchQuery, "")
    }

    func test_searchRows_nameTheMatchingAction() {
        let audio = AppShellSearchAction(
            addonName: "Audio",
            actionTitle: "Mute microphone",
            qualifiedID: "jugnu.audio.mute"
        )
        let clock = AppShellSearchAction(
            addonName: "World Clock",
            actionTitle: "Add city",
            qualifiedID: "jugnu.clock.add"
        )
        let rows = appShellSearchRows(actions: [audio, clock], query: "mute")
        XCTAssertEqual(rows, [.action(audio)])
    }

    func test_typeToSearch_keepsOnePrintableCharacter() {
        XCTAssertEqual(appShellTypeToSearchQuery("m"), "m")
        XCTAssertNil(appShellTypeToSearchQuery(" "))
        XCTAssertNil(appShellTypeToSearchQuery("ab"))
        XCTAssertNil(appShellTypeToSearchQuery("\n"))
    }

    func test_escapeAndCommandW_followTheFrameRoutes() {
        let home = presentAppShell(in: visible)
        XCTAssertNil(appShellSurface(after: .escape, surface: home))
        XCTAssertNil(appShellSurface(after: .commandW, surface: home))
        XCTAssertEqual(appShellSurface(after: .clickOutside, surface: home), home)

        var search = openAppShellSearch(on: home, query: "mute")
        search.navigation.homeScroll = 20
        let restored = appShellSurface(after: .escape, surface: search)
        XCTAssertEqual(restored?.frame, home.frame)
        XCTAssertEqual(restored?.navigation.page, .home)
        XCTAssertEqual(restored?.navigation.homeScroll, 20)
        XCTAssertEqual(restored?.navigation.searchQuery, "")
        XCTAssertEqual(appShellSurface(after: .searchBackdrop, surface: search), restored)
        XCTAssertEqual(appShellSurface(after: .clickOutside, surface: search)?.navigation.page, .search)

        let catalog = showAppShellPage(.catalog, on: home)
        XCTAssertEqual(appShellSurface(after: .clickOutside, surface: catalog), catalog)
        XCTAssertEqual(appShellSurface(after: .escape, surface: catalog)?.navigation.page, .home)
        XCTAssertEqual(appShellSurface(after: .commandW, surface: catalog)?.frame, home.frame)

        var detail = catalog
        detail.navigation.catalog.detail = AddonDetailRoute(addonID: "jugnu.audio", section: .actions)
        let popped = appShellSurface(after: .escape, surface: detail)
        XCTAssertEqual(popped?.frame, home.frame)
        XCTAssertEqual(popped?.navigation.page, .catalog)
        XCTAssertNil(popped?.navigation.catalog.detail)

        let preferences = showAppShellPage(.preferences, on: home)
        XCTAssertEqual(appShellSurface(after: .clickOutside, surface: preferences), preferences)
        XCTAssertEqual(appShellSurface(after: .invokeHotkey, surface: preferences)?.navigation.page, .home)
        XCTAssertEqual(appShellSurface(after: .commandW, surface: preferences)?.navigation.page, .home)
    }
}
