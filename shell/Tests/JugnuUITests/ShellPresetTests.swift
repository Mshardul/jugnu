import XCTest
@testable import JugnuUI

final class ShellPresetTests: XCTestCase {
    func test_launcherSize_compactWhenEmpty() {
        XCTAssertEqual(ShellPreset.launcher.size(compactLauncher: true).height, 120, accuracy: 0.5)
    }

    func test_launcherSize_fullWhenRows() {
        let size = ShellPreset.launcher.size(compactLauncher: false)
        XCTAssertEqual(size.width, 560, accuracy: 0.5)
        XCTAssertEqual(size.height, 360, accuracy: 0.5)
    }

    func test_catalogSize() {
        let size = ShellPreset.catalog.size(compactLauncher: false)
        XCTAssertEqual(size.width, 800, accuracy: 0.5)
        XCTAssertEqual(size.height, 560, accuracy: 0.5)
    }

    func test_detailHasNoSidebar() {
        XCTAssertFalse(ShellPreset.detail.hasSidebar)
    }

    func test_catalogHasSidebar() {
        XCTAssertTrue(ShellPreset.catalog.hasSidebar)
    }
}
