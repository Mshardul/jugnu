@testable import JugnuCore
import XCTest

final class AppUpdateSkipTests: XCTestCase {
    func testHappyPathDoesNotSkip() {
        XCTAssertFalse(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: false,
                bundlePath: "/Applications/Jugnu.app",
                env: [:],
                isDebug: false
            )
        )
    }

    func testFirstRunIncompleteSkips() {
        XCTAssertTrue(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: false,
                screenshotMode: false,
                bundlePath: "/Applications/Jugnu.app",
                env: [:],
                isDebug: false
            )
        )
    }

    func testScreenshotDebugBuildPathAndEnvSkip() {
        XCTAssertTrue(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: true,
                bundlePath: "/Applications/Jugnu.app",
                env: [:],
                isDebug: false
            )
        )
        XCTAssertTrue(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: false,
                bundlePath: "/Applications/Jugnu.app",
                env: [:],
                isDebug: true
            )
        )
        XCTAssertTrue(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: false,
                bundlePath: "/Users/me/jugnu/.build/debug/Jugnu.app",
                env: [:],
                isDebug: false
            )
        )
        XCTAssertTrue(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: false,
                bundlePath: "/Users/me/Library/Developer/Xcode/DerivedData/Jugnu/Build/Products/Debug/Jugnu.app",
                env: [:],
                isDebug: false
            )
        )
        XCTAssertTrue(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: false,
                bundlePath: "/Applications/Jugnu.app",
                env: ["JUGNU_SKIP_APP_UPDATE": "1"],
                isDebug: false
            )
        )
        XCTAssertFalse(
            AppUpdateSkip.shouldSkipAppCheck(
                firstRunCompleted: true,
                screenshotMode: false,
                bundlePath: "/Applications/Jugnu.app",
                env: ["JUGNU_SKIP_APP_UPDATE": ""],
                isDebug: false
            )
        )
    }

    func testAddonLaunchSkip() {
        XCTAssertTrue(AppUpdateSkip.shouldSkipAddonLaunchCheck(firstRunCompleted: false, screenshotMode: false))
        XCTAssertTrue(AppUpdateSkip.shouldSkipAddonLaunchCheck(firstRunCompleted: true, screenshotMode: true))
        XCTAssertFalse(AppUpdateSkip.shouldSkipAddonLaunchCheck(firstRunCompleted: true, screenshotMode: false))
    }
}
