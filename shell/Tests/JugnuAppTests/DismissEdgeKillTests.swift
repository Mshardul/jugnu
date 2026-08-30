@testable import Jugnu
import JugnuCore
import XCTest

@MainActor
final class DismissEdgeKillTests: XCTestCase {
    private func fixtureRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("JugnuCoreTests/Fixtures/misbehaving")
    }

    private func markerDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func spawnSleeper(_ dir: URL) throws -> RunningInvocation {
        try AddonRunner().spawn(
            addonRoot: fixtureRoot(),
            entrypoint: Entrypoint(kind: "exec", path: "sleep-forever"),
            request: RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:]),
            markerDir: dir
        )
    }

    private func track(
        _ inv: RunningInvocation,
        key: CommandKey,
        uuid: UUID,
        host: AddonProcessHost
    ) {
        host.register(key: key, entry: AddonProcessHost.Entry(
            invocation: inv,
            invocationTask: nil,
            lifecycleClass: .oneshot,
            startedAt: Date(),
            invokeUUID: uuid,
            markerPath: inv.markerURL,
            phase: .live
        ))
        let markerDir = inv.markerURL.deletingLastPathComponent()
        let pid = inv.process.processIdentifier
        inv.process.terminationHandler = { _ in
            RunMarker.delete(pid: pid, in: markerDir)
            Task { @MainActor in host.deregister(key: key, invokeUUID: uuid) }
        }
    }

    private func waitUntil(_ deadline: Date = Date().addingTimeInterval(3), _ cond: () -> Bool) {
        while !cond(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func test_dismiss_leavesNoTrackedProcess() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        let key = CommandKey(addonID: "demo", commandID: "demo")
        track(inv, key: key, uuid: UUID(), host: host)
        XCTAssertTrue(host.hasTracked(key: key))

        host.killTracked(key: key)

        waitUntil { !inv.process.isRunning }
        XCTAssertFalse(inv.process.isRunning)
        waitUntil { host.tracked().isEmpty }
        XCTAssertTrue(host.tracked().isEmpty)
    }

    func test_quit_killAll_isParallelAndBounded() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        var invs: [RunningInvocation] = []
        for i in 0 ..< 5 {
            let inv = try spawnSleeper(dir)
            invs.append(inv)
            track(inv, key: CommandKey(addonID: "a", commandID: "\(i)"), uuid: UUID(), host: host)
        }
        let start = Date()
        host.killAll()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, Double(LatencyBudgets.killGraceMs) / 1000 + 0.4)
        for inv in invs {
            waitUntil { !inv.process.isRunning }
            XCTAssertFalse(inv.process.isRunning)
        }
    }

    func test_clickOutside_and_esc_bothCancelViaKillTracked() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let a = try spawnSleeper(dir)
        let b = try spawnSleeper(dir)
        let keyA = CommandKey(addonID: "x", commandID: "1")
        let keyB = CommandKey(addonID: "y", commandID: "2")
        track(a, key: keyA, uuid: UUID(), host: host)
        track(b, key: keyB, uuid: UUID(), host: host)

        host.killTracked(key: keyA)
        host.killTracked(key: keyB)

        for inv in [a, b] {
            waitUntil { !inv.process.isRunning }
            XCTAssertFalse(inv.process.isRunning)
        }
    }
}
