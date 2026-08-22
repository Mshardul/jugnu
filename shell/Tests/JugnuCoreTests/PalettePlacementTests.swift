import XCTest
@testable import JugnuCore

final class PalettePlacementTests: XCTestCase {
    func testMouseOnSecondScreen() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        ]
        XCTAssertEqual(
            PalettePlacement.screenIndex(frames: frames, mouse: CGPoint(x: 2000, y: 100)),
            1
        )
        XCTAssertEqual(
            PalettePlacement.screenIndex(frames: frames, mouse: CGPoint(x: 10, y: 10)),
            0
        )
        XCTAssertNil(PalettePlacement.screenIndex(frames: frames, mouse: CGPoint(x: -20, y: 0)))
    }
}
