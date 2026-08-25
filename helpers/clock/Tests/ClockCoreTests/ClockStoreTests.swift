import Foundation
import XCTest
@testable import ClockCore

final class ClockStoreTests: XCTestCase {
    func testUpsertAndDue() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clock-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ClockStore(fileURL: url)
        let past = Date().addingTimeInterval(-1)
        try store.upsert(ClockTimer(
            id: "nudges:eyes",
            kind: .interval,
            intervalSeconds: 1200,
            fireAt: nil,
            enabled: true,
            paused: false,
            nextFire: past,
            group: "nudges",
            target: ClockTarget(addon: "nudges", command: "show-card")
        ))
        XCTAssertEqual(try store.due(now: Date()).map(\.id), ["nudges:eyes"])
    }

    func testPausedNotDue() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        try store.upsert(makeTimer(id: "paused", paused: true))

        XCTAssertEqual(try store.due(now: referenceDate), [])
    }

    func testMarkFiredAdvancesInterval() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let now = referenceDate
        try store.upsert(makeTimer(id: "interval", intervalSeconds: 1_200))

        try store.markFired(id: "interval", now: now)

        let timer = try XCTUnwrap(try store.list().first)
        XCTAssertEqual(timer.nextFire, now.addingTimeInterval(1_200))
    }

    func testPauseAndResumeByGroup() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try store.upsert(makeTimer(id: "nudges:eyes", group: "nudges"))
        try store.upsert(makeTimer(id: "other:timer", group: "other"))

        try store.pause(group: "nudges")

        XCTAssertEqual(try store.due(now: referenceDate).map(\.id), ["other:timer"])

        try store.resume(group: "nudges")

        XCTAssertEqual(try store.due(now: referenceDate).map(\.id), ["nudges:eyes", "other:timer"])
    }

    func testCancelRemovesTimer() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try store.upsert(makeTimer(id: "cancelled"))

        try store.cancel(id: "cancelled")

        XCTAssertEqual(try store.list(), [])
    }

    func testPersistReload() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let timer = makeTimer(id: "persisted")
        try store.upsert(timer)

        let reloaded = ClockStore(fileURL: url)

        XCTAssertEqual(try reloaded.list(), [timer])
    }

    func testSnoozeMovesNextFire() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try store.upsert(makeTimer(id: "snoozed"))

        try store.snooze(id: "snoozed", seconds: 300, now: referenceDate)

        let timer = try XCTUnwrap(try store.list().first)
        XCTAssertEqual(timer.nextFire, referenceDate.addingTimeInterval(300))
    }

    func testMarkFiredRemovesOneShot() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try store.upsert(ClockTimer(
            id: "one-shot",
            kind: .oneShot,
            intervalSeconds: nil,
            fireAt: referenceDate,
            enabled: true,
            paused: false,
            nextFire: referenceDate,
            group: nil,
            target: ClockTarget(addon: "timer", command: "ring")
        ))

        try store.markFired(id: "one-shot", now: referenceDate)

        XCTAssertEqual(try store.list(), [])
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 2_000_000_000)
    }

    private func makeStore() -> (ClockStore, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clock-\(UUID().uuidString).json")
        return (ClockStore(fileURL: url), url)
    }

    private func makeTimer(
        id: String,
        intervalSeconds: Int = 1_200,
        paused: Bool = false,
        group: String? = "nudges"
    ) -> ClockTimer {
        ClockTimer(
            id: id,
            kind: .interval,
            intervalSeconds: intervalSeconds,
            fireAt: nil,
            enabled: true,
            paused: paused,
            nextFire: referenceDate.addingTimeInterval(-1),
            group: group,
            target: ClockTarget(addon: "nudges", command: "show-card")
        )
    }
}
