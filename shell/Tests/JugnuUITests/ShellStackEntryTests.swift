import XCTest
@testable import JugnuUI

final class ShellStackEntryTests: XCTestCase {
    func test_launcherState_mapsToLauncherPreset() {
        let entry = ShellStackEntry(.launcher(query: "", selection: nil, scroll: 0))
        XCTAssertEqual(entry.preset, .launcher)
    }

    func test_catalogState_mapsToCatalogPreset() {
        let entry = ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil))
        XCTAssertEqual(entry.preset, .catalog)
    }

    func test_detailState_mapsToDetailPreset() {
        let entry = ShellStackEntry(.detail(addonID: "mic-mute"))
        XCTAssertEqual(entry.preset, .detail)
    }

    func test_equality_sameCaseSameValues() {
        XCTAssertEqual(
            ShellStackEntry(.confirm),
            ShellStackEntry(.confirm)
        )
    }
}
