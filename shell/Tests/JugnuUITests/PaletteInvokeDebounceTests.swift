@testable import JugnuUI
import XCTest

final class PaletteInvokeDebounceTests: XCTestCase {
    func test_firstInvoke_runs() {
        XCTAssertTrue(PaletteInvokeDebounce.shouldRun(id: "a.b", now: Date(), last: nil))
    }

    func test_repeatOfSameCommandInsideWindow_isDropped() {
        let t0 = Date()
        let inside = t0.addingTimeInterval(PaletteInvokeDebounce.windowSeconds / 2)
        XCTAssertFalse(PaletteInvokeDebounce.shouldRun(id: "a.b", now: inside, last: ("a.b", t0)))
    }

    func test_repeatOfSameCommandAfterWindow_runs() {
        let t0 = Date()
        let after = t0.addingTimeInterval(PaletteInvokeDebounce.windowSeconds + 0.01)
        XCTAssertTrue(PaletteInvokeDebounce.shouldRun(id: "a.b", now: after, last: ("a.b", t0)))
    }

    func test_differentCommandInsideWindow_runs() {
        let t0 = Date()
        let inside = t0.addingTimeInterval(PaletteInvokeDebounce.windowSeconds / 2)
        XCTAssertTrue(PaletteInvokeDebounce.shouldRun(id: "c.d", now: inside, last: ("a.b", t0)))
    }
}
