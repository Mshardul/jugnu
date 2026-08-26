import Foundation
@testable import JugnuCore
import XCTest

@MainActor
final class ClockHostTests: XCTestCase {
    func testTickInvokesActiveDueTimerAndMarksItFired() async {
        let timer = makeTimer(id: "opaque:timer-id")
        let service = FakeClockService(dueTimers: [timer])
        let host = ClockHost(service: service)
        var invocations: [(target: ClockTarget, timerID: String)] = []

        await host.tick(now: Date(timeIntervalSince1970: 1000)) { addon, command, timerID in
            invocations.append((ClockTarget(addon: addon, command: command), timerID))
        }

        XCTAssertEqual(invocations.map(\.target), [timer.target])
        XCTAssertEqual(invocations.map(\.timerID), ["opaque:timer-id"])
        XCTAssertEqual(service.markedIDs, ["opaque:timer-id"])
    }

    func testTickDoesNotInvokePausedTimer() async {
        let service = FakeClockService(dueTimers: [makeTimer(id: "paused", paused: true)])
        let host = ClockHost(service: service)
        var invocationCount = 0

        await host.tick(now: Date()) { _, _, _ in invocationCount += 1 }

        XCTAssertEqual(invocationCount, 0)
        XCTAssertEqual(service.markedIDs, [])
    }

    func testTickLeavesFailedTimerDueOnceThenMarksItFired() async {
        let service = FakeClockService(dueTimers: [makeTimer(id: "failing")])
        var errors: [String] = []
        let host = ClockHost(service: service, onError: { errors.append($0) })

        await host.tick(now: Date()) { _, _, _ in throw TestError.failed }
        XCTAssertEqual(service.markedIDs, [])

        await host.tick(now: Date()) { _, _, _ in throw TestError.failed }
        XCTAssertEqual(service.markedIDs, ["failing"])
        XCTAssertEqual(errors, ["Clock command failed.", "Clock command failed."])
    }

    func testTimerDoesNotOverlapSlowTick() async {
        let service = FakeClockService(dueTimers: [makeTimer(id: "slow")])
        let host = ClockHost(service: service)
        var invocationCount = 0

        host.start { _, _, _ in
            invocationCount += 1
            try await Task.sleep(nanoseconds: 2_500_000_000)
        }
        try? await Task.sleep(nanoseconds: 4_200_000_000)
        host.stop()

        XCTAssertEqual(invocationCount, 1)
    }

    func testMarkFailureDoesNotInvokeCommandAgain() async {
        let service = FakeClockService(
            dueTimers: [makeTimer(id: "mark-fails")],
            markFailuresRemaining: 1
        )
        var errors: [String] = []
        let host = ClockHost(service: service, onError: { errors.append($0) })
        var invocationCount = 0

        await host.tick(now: Date()) { _, _, _ in invocationCount += 1 }
        await host.tick(now: Date()) { _, _, _ in invocationCount += 1 }

        XCTAssertEqual(invocationCount, 1)
        XCTAssertEqual(service.markedIDs, ["mark-fails"])
        XCTAssertEqual(errors, ["Clock command failed."])
    }

    private func makeTimer(id: String, paused: Bool = false) -> ClockTimer {
        ClockTimer(
            id: id,
            kind: .oneShot,
            intervalSeconds: nil,
            fireAt: Date(timeIntervalSince1970: 1000),
            enabled: true,
            paused: paused,
            nextFire: Date(timeIntervalSince1970: 1000),
            group: nil,
            target: ClockTarget(addon: "nudges", command: "show")
        )
    }
}

private enum TestError: Error {
    case failed
}

private final class FakeClockService: ClockServicing, @unchecked Sendable {
    private let lock = NSLock()
    private let dueTimers: [ClockTimer]
    private(set) var markedIDs: [String] = []
    private var markFailuresRemaining: Int

    init(dueTimers: [ClockTimer], markFailuresRemaining: Int = 0) {
        self.dueTimers = dueTimers
        self.markFailuresRemaining = markFailuresRemaining
    }

    func due(now _: Date) throws -> [ClockTimer] {
        dueTimers
    }

    func markFired(id: String, now _: Date) throws {
        try lock.withLock {
            if markFailuresRemaining > 0 {
                markFailuresRemaining -= 1
                throw TestError.failed
            }
            markedIDs.append(id)
        }
    }
}
