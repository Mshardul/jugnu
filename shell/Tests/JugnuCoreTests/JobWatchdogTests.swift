@testable import JugnuCore
import XCTest

final class JobWatchdogTests: XCTestCase {
    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/misbehaving")
        )
    }

    private func markerDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func spawn(_ name: String, dir: URL) throws -> RunningInvocation {
        let url = try fixture(name)
        return try AddonRunner().spawn(
            addonRoot: url.deletingLastPathComponent(),
            entrypoint: Entrypoint(kind: "exec", path: url.lastPathComponent),
            request: RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:]),
            lifecycleClass: .job,
            markerDir: dir
        )
    }

    func test_sleepForever_jobHandshakeTimeout() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try spawn("sleep-forever", dir: dir)
        defer { inv.killImmediately() }
        do {
            _ = try await inv.waitForJobResponse(handshakeWindow: 0.25, heartbeatWindow: 2)
            XCTFail("expected handshake timeout")
        } catch AddonRunnerError.jobHandshakeTimeout {
            XCTAssertFalse(inv.process.isRunning)
        }
    }

    func test_stopsHeartbeating_jobUnresponsive() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try spawn("heartbeat-then-hang", dir: dir)
        defer { inv.killImmediately() }
        do {
            _ = try await inv.waitForJobResponse(handshakeWindow: 1, heartbeatWindow: 0.3)
            XCTFail("expected unresponsive")
        } catch AddonRunnerError.jobUnresponsive {
            XCTAssertFalse(inv.process.isRunning)
        }
    }

    func test_heartbeatsPastWindow_notKilled() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try spawn("heartbeats-forever", dir: dir)
        defer { inv.killImmediately() }
        let waiter = Task {
            try await inv.waitForJobResponse(handshakeWindow: 1, heartbeatWindow: 0.25)
        }
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(inv.process.isRunning)
        inv.killImmediately()
        waiter.cancel()
        _ = await waiter.result
    }

    func test_fastExitJob_decodesJSONAfterHeartbeats() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try spawn("fast-exit", dir: dir)
        let response = try await inv.waitForJobResponse(handshakeWindow: 2, heartbeatWindow: 2)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.message, "done")
    }
}

final class JobProgressCopyTests: XCTestCase {
    func test_labelSoftensAfterSixtySeconds() {
        XCTAssertEqual(JobProgressCopy.label(elapsed: 0), JobProgressCopy.working)
        XCTAssertEqual(JobProgressCopy.label(elapsed: 59), JobProgressCopy.working)
        XCTAssertEqual(JobProgressCopy.label(elapsed: 60), JobProgressCopy.stillWorking)
    }
}
