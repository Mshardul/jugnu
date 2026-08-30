import Foundation
@testable import JugnuCore
import XCTest

final class SingleInstanceTests: XCTestCase {
    private func info(pid: Int, launched: TimeInterval) -> RunningInstance {
        RunningInstance(pid: pid, launchDate: Date(timeIntervalSince1970: launched))
    }

    func testAloneDoesNotYield() {
        let me = info(pid: 100, launched: 10)
        XCTAssertFalse(SingleInstance.shouldYield(running: [me], selfPID: 100))
    }

    func testYieldsToAnEarlierInstance() {
        let older = info(pid: 90, launched: 5)
        let me = info(pid: 100, launched: 10)
        XCTAssertTrue(SingleInstance.shouldYield(running: [older, me], selfPID: 100))
    }

    func testOlderInstanceDoesNotYieldToLaterOne() {
        let me = info(pid: 90, launched: 5)
        let newer = info(pid: 100, launched: 10)
        XCTAssertFalse(SingleInstance.shouldYield(running: [me, newer], selfPID: 90))
    }

    func testEqualLaunchDatesBreakTieByLowerPID() {
        let a = info(pid: 90, launched: 5)
        let b = info(pid: 100, launched: 5)
        XCTAssertFalse(SingleInstance.shouldYield(running: [a, b], selfPID: 90))
        XCTAssertTrue(SingleInstance.shouldYield(running: [a, b], selfPID: 100))
    }

    func testSelfNotInListDoesNotYield() {
        let other = info(pid: 90, launched: 5)
        XCTAssertFalse(SingleInstance.shouldYield(running: [other], selfPID: 100))
    }
}
