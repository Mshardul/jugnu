import XCTest

/// Walks Jugnu the way a user would and screenshots every page along the way.
/// Run manually via `make screenshots` (never part of `make test` or CI).
///
/// Screenshots are attached to the test result; `make screenshots` extracts
/// them from the `.xcresult` bundle into `screenshots/NN-name.png`.
final class ScreenshotFlow: XCTestCase {
    var app: XCUIApplication!
    private var step = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["JUGNU_SCREENSHOT_MODE"] = "1"
        if let repoAddons = ProcessInfo.processInfo.environment["JUGNU_REPO_ADDONS"] {
            app.launchEnvironment["JUGNU_REPO_ADDONS"] = repoAddons
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    /// Screenshot the whole screen (captures floating panels regardless of AX visibility).
    private func shot(_ name: String) {
        step += 1
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = String(format: "%02d-%@", step, name)
        a.lifetime = .keepAlways
        add(a)
        NSLog("SHOT: \(a.name!)")
    }

    private func openPalette() {
        let menuBar = app.menuBars.element(boundBy: 0)
        let statusItem = menuBar.statusItems.element(boundBy: 0)
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "menu-bar status item")
        statusItem.click()
        let openPalette = app.menuItems["Open Palette"]
        XCTAssertTrue(openPalette.waitForExistence(timeout: 5), "'Open Palette' menu item")
        openPalette.click()
        _ = app.windows.element(boundBy: 0).waitForExistence(timeout: 5)
        usleep(600_000)
    }

    // MARK: - The walk

    func testWalkEveryPage() throws {
        // 1. Launcher, empty.
        openPalette()
        shot("launcher-empty")

        // 2. Type a query -> search results.
        let field = app.textFields.element(boundBy: 0)
        if field.waitForExistence(timeout: 5) {
            field.click()
            field.typeText("toggle")
            usleep(500_000)
            shot("launcher-search-results")

            // 3. Arrow down to move the selection.
            field.typeKey(.downArrow, modifierFlags: [])
            usleep(200_000)
            shot("launcher-selection-moved")

            // 4. Clear -> first view / favorites bar.
            let clear = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8)
            field.typeText(clear)
            usleep(400_000)
            shot("launcher-favorites-bar")
        } else {
            NSLog("SHOT: search field not found — skipping query steps")
        }

        // 5. Open the catalog ("Show all addons" / "All addons").
        if clickFirstHittable(labels: ["Show all addons →", "⚙︎ All addons", "All addons"]) {
            usleep(800_000)
            shot("catalog")

            // 6. Filter by a sidebar category.
            if clickFirstHittable(labels: ["Developer", "Audio", "System"]) {
                usleep(500_000)
                shot("catalog-category-filtered")
            }

            // 7. Type in the catalog search.
            let catSearch = app.textFields.element(boundBy: 0)
            if catSearch.exists {
                catSearch.click()
                catSearch.typeText("mic")
                usleep(500_000)
                shot("catalog-search-filtered")
                catSearch.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
                usleep(300_000)
            }

            // 8. Open an addon card -> detail.
            let card = app.staticTexts["Mic Mute"]
            if card.waitForExistence(timeout: 3), card.isHittable {
                card.click()
                usleep(600_000)
                shot("addon-detail")
                // Back out.
                app.typeKey(.escape, modifierFlags: [])
                usleep(400_000)
            }
        }

        // 9. Open Preferences.
        // From the catalog the launcher chrome isn't visible; go via the menu-bar item.
        let menuBar = app.menuBars.element(boundBy: 0)
        menuBar.statusItems.element(boundBy: 0).click()
        let prefsItem = app.menuItems["Preferences…"]
        if prefsItem.waitForExistence(timeout: 3) {
            prefsItem.click()
            usleep(800_000)
            shot("preferences")

            // 10. Change the theme.
            if clickFirstHittable(labels: ["Terminal Phosphor", "Rose Quartz"]) {
                usleep(500_000)
                shot("preferences-theme-changed")
            }
        }

        // 11-13. Keyboard panels: run the ui-demo commands from the palette.
        for (query, name) in [
            ("confirm", "panel-confirm"),
            ("list", "panel-list"),
            ("form", "panel-form"),
        ] {
            openPalette()
            let f = app.textFields.element(boundBy: 0)
            guard f.waitForExistence(timeout: 4) else { continue }
            f.click()
            f.typeText(query)
            usleep(500_000)
            f.typeKey(.enter, modifierFlags: [])
            usleep(800_000)
            shot(name)
            app.typeKey(.escape, modifierFlags: [])
            usleep(300_000)
        }

        // 14. The menu-bar menu itself.
        menuBar.statusItems.element(boundBy: 0).click()
        usleep(400_000)
        shot("menu-bar-menu")
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Click the first hittable element (button or static text) matching any label.
    @discardableResult
    private func clickFirstHittable(labels: [String]) -> Bool {
        for label in labels {
            for q in [app.buttons[label], app.staticTexts[label], app.otherElements[label]] {
                if q.exists, q.isHittable {
                    q.click()
                    return true
                }
            }
        }
        NSLog("SHOT: none hittable among \(labels)")
        return false
    }
}
