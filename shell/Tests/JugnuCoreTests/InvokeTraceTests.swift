import XCTest
@testable import JugnuCore

final class InvokeTraceTests: XCTestCase {
    func testFirstPaintDelta() {
        final class Clock: @unchecked Sendable {
            var t: TimeInterval = 1_000
        }
        let clock = Clock()
        let trace = InvokeTrace(commandId: "x", now: { Date(timeIntervalSince1970: clock.t) })
        clock.t += 0.08
        trace.markFirstPaint()
        XCTAssertEqual(trace.firstPaintMs, 80)
    }
}
