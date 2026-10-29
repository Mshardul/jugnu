import AppKit
import JugnuCore
@testable import JugnuUI
import SwiftUI
import XCTest

final class ShellHostFrameTests: XCTestCase {
    func testGridPresetDefaultsToGridViewType() {
        XCTAssertEqual(ShellPreset.grid.defaultViewType(compactLauncher: false), .grid)
        XCTAssertEqual(ShellPreset.grid.defaultViewType(compactLauncher: true), .grid)
    }

    func test_traySelection_replacesOnAPlainClick() {
        XCTAssertEqual(traySelection(current: ["a", "b"], clicked: "c", adding: false), ["c"])
    }

    func test_traySelection_togglesWhenAdding() {
        XCTAssertEqual(traySelection(current: ["a"], clicked: "b", adding: true), ["a", "b"])
        XCTAssertEqual(traySelection(current: ["a", "b"], clicked: "a", adding: true), ["b"])
    }

    func test_trayMenuSelection_keepsTheGroupWhenTheClickIsInsideIt() {
        XCTAssertEqual(trayMenuSelection(current: ["a", "b"], clicked: "a"), ["a", "b"])
        XCTAssertEqual(trayMenuSelection(current: ["a", "b"], clicked: "c"), ["c"])
    }

    func test_trayFrame_hangsFromTheTopOfTheVisibleFrame() {
        let visible = NSRect(x: 0, y: 90, width: 1440, height: 779)
        let frame = trayFrame(in: visible)
        XCTAssertEqual(frame.maxY, visible.maxY, accuracy: 0.5)
        XCTAssertEqual(frame.midX, visible.midX, accuracy: 0.5)
        XCTAssertLessThanOrEqual(frame.maxX, visible.maxX)
        XCTAssertGreaterThanOrEqual(frame.minX, visible.minX)
    }

    func test_clampedFrame_centersWithinScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 560)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(frame.midY, screen.midY, accuracy: 0.5)
    }

    func test_clampedFrame_shrinksWhenLargerThanScreen() {
        let screen = NSRect(x: 0, y: 0, width: 400, height: 300)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertLessThanOrEqual(frame.width, screen.width)
        XCTAssertLessThanOrEqual(frame.height, screen.height)
    }

    func test_clampedFrame_staysInsideScreenBounds() {
        let screen = NSRect(x: 100, y: 50, width: 1440, height: 900)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertTrue(screen.contains(CGPoint(x: frame.minX, y: frame.minY)))
        XCTAssertTrue(screen.contains(CGPoint(x: frame.maxX - 1, y: frame.maxY - 1)))
    }

    @MainActor
    func test_hide_keepsPanelAliveForReuse() {
        let host = ShellHost(reduceMotion: { true })
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 400, height: 300))
        XCTAssertTrue(host.hasPanel)

        host.hide()

        XCTAssertTrue(host.hasPanel, "hide() must keep the panel so the next invoke skips a rebuild")
        XCTAssertFalse(host.isVisible)
    }

    @MainActor
    func test_ensurePanel_doesNotRebuildWhenPanelAlreadyExists() {
        let host = ShellHost(reduceMotion: { true })
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 400, height: 300))
        host.hide()
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 400, height: 300))

        XCTAssertTrue(host.hasPanel)
        XCTAssertFalse(host.isVisible, "re-ensuring a hidden panel must not order it front on its own")
    }

    @MainActor
    func test_placeAppShellFrame_insetsTheVisibleFrame() {
        let host = ShellHost(reduceMotion: { true })
        let visible = NSRect(x: 100, y: 80, width: 1440, height: 900)
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 100, height: 80))
        host.showAppShell(.freshHome())
        host.placeAppShellFrame(in: visible)

        let frame = host.panelFrame
        XCTAssertEqual(frame?.minX ?? -1, 132, accuracy: 0.5)
        XCTAssertEqual(frame?.minY ?? -1, 112, accuracy: 0.5)
        XCTAssertEqual(frame?.width ?? 0, 1376, accuracy: 0.5)
        XCTAssertEqual(frame?.height ?? 0, 836, accuracy: 0.5)
        XCTAssertFalse(host.dismissesOnOutsideClick)
    }

    @MainActor
    func test_pageSwapAndSearch_keepTheSamePanelFrame() {
        let host = ShellHost(reduceMotion: { true })
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 100, height: 80))
        host.showAppShell(.freshHome())
        host.placeAppShellFrame(in: visible)
        let frame = host.panelFrame

        host.updateAppShell(AppNavigation(page: .catalog))
        host.updateAppShell(AppNavigation(page: .preferences))
        var search = AppNavigation.freshHome()
        search.page = .search
        search.searchQuery = "mute"
        host.updateAppShell(search)

        XCTAssertEqual(host.panelFrame, frame)
        XCTAssertTrue(host.hasPanel)
        XCTAssertEqual(host.appShellNavigation?.page, .search)
        XCTAssertFalse(host.dismissesOnOutsideClick)
    }

    @MainActor
    func test_viewTypePanel_stillResizesAndTheAppShellFrameReturns() {
        let host = ShellHost(reduceMotion: { true })
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 100, height: 80))
        host.showAppShell(.freshHome())
        host.placeAppShellFrame(in: visible)
        let home = host.panelFrame

        host.push(ShellStackEntry(.list(query: "", highlightedID: nil, scroll: 0)))
        host.morphFrame(to: .list, compactLauncher: false, in: visible, viewType: .rows)
        XCTAssertNotEqual(host.panelFrame?.width, home?.width)
        XCTAssertTrue(host.dismissesOnOutsideClick)

        XCTAssertTrue(host.popTop())
        host.morphFrame(to: .appShell, compactLauncher: false, in: visible)
        XCTAssertEqual(host.panelFrame, home)
        XCTAssertFalse(host.dismissesOnOutsideClick)
    }

    @MainActor
    func test_commandW_reachesTheAppShellHandler() {
        let host = ShellHost(reduceMotion: { true })
        host.ensurePanel(initialContent: EmptyView(), size: NSSize(width: 200, height: 120))
        var closed = false
        host.setOnCommandW { closed = true }
        XCTAssertTrue(host.performCommandW())
        XCTAssertTrue(closed)
    }
}
