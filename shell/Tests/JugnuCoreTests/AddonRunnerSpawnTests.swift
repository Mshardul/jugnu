@testable import JugnuCore
import XCTest

final class AddonRunnerSpawnTests: XCTestCase {
    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/misbehaving")
        )
    }

    private func markerDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func request() -> RunRequest {
        RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:])
    }

    private func entrypoint(for url: URL) -> (root: URL, entry: Entrypoint) {
        (url.deletingLastPathComponent(), Entrypoint(kind: "exec", path: url.lastPathComponent))
    }

    func test_spawn_returnsLiveHandle_processIsRunning() throws {
        let (root, entry) = try entrypoint(for: fixture("sleep-forever"))
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try AddonRunner().spawn(addonRoot: root, entrypoint: entry, request: request(), markerDir: dir)
        XCTAssertTrue(inv.process.isRunning)
        inv.terminate()
    }

    func test_waitForResponse_resolvesAndDrainsStdout() async throws {
        let (root, entry) = try entrypoint(for: fixture("fast-exit"))
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try AddonRunner().spawn(addonRoot: root, entrypoint: entry, request: request(), markerDir: dir)
        let response = try await inv.waitForResponse(timeout: 5)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.message, "done")
    }

    func test_terminate_killsChildWithinKillGrace() throws {
        let (root, entry) = try entrypoint(for: fixture("sleep-forever"))
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try AddonRunner().spawn(addonRoot: root, entrypoint: entry, request: request(), markerDir: dir)
        let start = Date()
        inv.terminate()
        while inv.process.isRunning, Date().timeIntervalSince(start) < 3 {
            usleep(20000)
        }
        XCTAssertFalse(inv.process.isRunning)
    }

    func test_terminate_sigtermIgnorer_escalatesToSIGKILL() throws {
        let (root, entry) = try entrypoint(for: fixture("sigterm-ignorer"))
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try AddonRunner().spawn(addonRoot: root, entrypoint: entry, request: request(), markerDir: dir)
        usleep(200_000)
        let start = Date()
        inv.terminate()
        while inv.process.isRunning, Date().timeIntervalSince(start) < 3 {
            usleep(20000)
        }
        XCTAssertFalse(inv.process.isRunning)
        XCTAssertGreaterThan(Date().timeIntervalSince(start), Double(LatencyBudgets.killGraceMs) / 1000 * 0.5)
    }

    func test_spawn_writesMarker_terminationDeletesIt() throws {
        let (root, entry) = try entrypoint(for: fixture("fast-exit"))
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inv = try AddonRunner().spawn(addonRoot: root, entrypoint: entry, request: request(), markerDir: dir)
        let pid = inv.process.processIdentifier
        let markerPath = dir.appendingPathComponent("\(pid).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerPath.path))
        inv.process.waitUntilExit()
        let deadline = Date().addingTimeInterval(2)
        while FileManager.default.fileExists(atPath: markerPath.path), Date() < deadline {
            usleep(20000)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerPath.path))
    }
}
