import XCTest
import JugnuCore

final class PrefsSelectionTests: XCTestCase {
    func testCasesAreStable() {
        XCTAssertEqual(
            PrefsSelection.allCases.map(\.rawValue),
            ["theme", "addonsInstalled", "addonsUpdates", "general"]
        )
    }

    func testDefaultIsTheme() {
        XCTAssertEqual(PrefsSelection.default, .theme)
    }
}
