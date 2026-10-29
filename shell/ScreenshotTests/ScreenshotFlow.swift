import AppKit
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

    /// Screenshot the Jugnu window only.
    private func shot(_ name: String) {
        step += 1
        let window = app.windows.element(boundBy: 0)
        let s = window.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = String(format: "%02d-%@", step, name)
        a.lifetime = .keepAlways
        add(a)
        NSLog("SHOT: \(a.name!)")
    }

    func testAppShellLaunch() throws {
        continueAfterFailure = false
        app.activate()
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.jugnu.open-palette"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        let favorites = app.staticTexts["Favorite Addons"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 8))
        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.exists)
        let home = window.frame
        NSLog("FRAME home \(NSStringFromRect(home))")
        assertShellSize(home)
        XCTAssertTrue(app.staticTexts["Favorite Addons"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Recent Activity"].exists)
        XCTAssertTrue(app.staticTexts["Updates"].exists)
        XCTAssertFalse(app.staticTexts["Running Work"].exists)
        shot("home")

        clickOutside(window)
        XCTAssertTrue(window.exists)
        XCTAssertEqual(window.frame, home)

        app.buttons["Catalog"].click()
        XCTAssertTrue(app.staticTexts["Discover"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["All Addons"].exists)
        XCTAssertFalse(app.staticTexts["Favorite Addons"].exists)
        XCTAssertEqual(window.frame, home, "Catalog keeps the shared frame")
        shot("catalog")
        if app.staticTexts["All Addons"].waitForExistence(timeout: 2) {
            app.staticTexts["All Addons"].click()
            shot("catalog-all")
            app.staticTexts["Discover"].click()
        }
        if app.staticTexts["UI Demo List"].waitForExistence(timeout: 2) {
            app.staticTexts["UI Demo List"].click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
            shot("addon-detail")
            if app.buttons["Actions"].waitForExistence(timeout: 1) {
                app.buttons["Actions"].click()
                shot("addon-actions")
            }
            if app.buttons["Settings"].waitForExistence(timeout: 1) {
                app.buttons["Settings"].click()
                shot("addon-settings")
            }
            app.buttons["Back"].click()
            XCTAssertTrue(app.staticTexts["Discover"].waitForExistence(timeout: 3))
        }

        app.buttons["Preferences"].click()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Firefly"].exists)
        XCTAssertEqual(window.frame, home, "Preferences keeps the shared frame")
        shot("preferences")
        if app.buttons["Installed"].waitForExistence(timeout: 2) {
            app.buttons["Installed"].click()
            shot("preferences-installed")
        }
        if app.buttons["Updates"].waitForExistence(timeout: 2) {
            app.buttons["Updates"].click()
            shot("preferences-updates")
        }
        if app.buttons["General"].waitForExistence(timeout: 2) {
            app.buttons["General"].click()
            shot("preferences-general")
        }
        app.buttons["Appearance"].click()
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Favorite Addons"].waitForExistence(timeout: 3))
        XCTAssertEqual(window.frame, home, "Cmd+W on Preferences returns Home")

        app.buttons["Search"].click()
        let field = app.textFields["Search Jugnu"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(window.frame, home, "Search stays over the shared frame")
        field.click()
        field.typeText("demo list")
        shot("search")
        let action = app.buttons["UI Demo List › Demo list picker"]
        XCTAssertTrue(action.waitForExistence(timeout: 3), app.debugDescription)
        action.click()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
        let afterAction = window.frame
        NSLog("FRAME after action \(NSStringFromRect(afterAction))")
        if afterAction != home {
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertTrue(app.staticTexts["Favorite Addons"].waitForExistence(timeout: 3))
            XCTAssertEqual(window.frame, home, "leaving a follow-up restores the shared frame")
        }

        app.buttons["Search"].click()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.55)).click()
        XCTAssertFalse(field.exists)
        XCTAssertTrue(app.staticTexts["Favorite Addons"].waitForExistence(timeout: 3))
        XCTAssertEqual(window.frame, home, "search backdrop restores Home")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(window.waitForExistence(timeout: 2))
    }

    private func assertShellSize(_ frame: CGRect) {
        guard let screen = NSScreen.main else {
            XCTFail("no screen")
            return
        }
        let visible = screen.visibleFrame
        // Accessibility reports this borderless panel a few points off the
        // AppKit frame. The exact 32 pt inset is checked in ShellHostFrameTests.
        XCTAssertEqual(Double(frame.width), Double(visible.width - 64), accuracy: 4)
        XCTAssertEqual(Double(frame.height), Double(visible.height - 64), accuracy: 4)
    }

    private func clickOutside(_ window: XCUIElement) {
        window.coordinate(withNormalizedOffset: CGVector(dx: -0.02, dy: 0.4)).click()
        usleep(300_000)
    }

}
