@testable import Jugnu
import JugnuCore
import XCTest

@MainActor
final class OnReinvokeTests: XCTestCase {
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
            lifecycleClass: .job,
            markerDir: dir
        )
    }

    private func jobEntry(_ inv: RunningInvocation, uuid: UUID = UUID()) -> AddonProcessHost.Entry {
        AddonProcessHost.Entry(
            invocation: inv,
            invocationTask: nil,
            lifecycleClass: .job,
            startedAt: Date(),
            invokeUUID: uuid,
            markerPath: inv.markerURL,
            phase: .live
        )
    }

    func test_jobReuse_blocksSecondSpawn() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        defer { inv.killImmediately() }
        let key = CommandKey(addonID: "a", commandID: "work")
        host.register(key: key, entry: jobEntry(inv))
        let gate = await host.prepareJobSpawn(key: key, mode: .reuse, programmatic: false)
        XCTAssertEqual(gate, .reuse)
        XCTAssertEqual(host.tracked().count, 1)
        XCTAssertTrue(inv.process.isRunning)
    }

    func test_jobReplace_killsThenAllowsSpawn() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        defer { inv.killImmediately() }
        let key = CommandKey(addonID: "a", commandID: "work")
        host.register(key: key, entry: jobEntry(inv))
        let gate = await host.prepareJobSpawn(key: key, mode: .replace, programmatic: false)
        XCTAssertEqual(gate, .spawn)
        XCTAssertFalse(inv.process.isRunning)
    }

    func test_replaceStuckChild_stillStopping() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        host.replaceDeathCeiling = 0.05
        host.killJob = { _ in }
        let inv = try spawnSleeper(dir)
        defer { inv.killImmediately() }
        let key = CommandKey(addonID: "a", commandID: "work")
        host.register(key: key, entry: jobEntry(inv))
        let gate = await host.prepareJobSpawn(key: key, mode: .replace, programmatic: false)
        XCTAssertEqual(gate, .stillStopping)
        XCTAssertTrue(inv.process.isRunning)
    }

    func test_oneshotNeverBlocks() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        defer { inv.killImmediately() }
        let key = CommandKey(addonID: "a", commandID: "work")
        host.register(
            key: key,
            entry: AddonProcessHost.Entry(
                invocation: inv,
                invocationTask: nil,
                lifecycleClass: .oneshot,
                startedAt: Date(),
                invokeUUID: UUID(),
                markerPath: inv.markerURL,
                phase: .live
            )
        )
        let gate = await host.prepareJobSpawn(key: key, mode: .replace, programmatic: false)
        XCTAssertEqual(gate, .spawn)
        XCTAssertTrue(inv.process.isRunning)
    }

    func test_programmaticCollision_reusesRegardlessOfReplace() async throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        defer { inv.killImmediately() }
        let key = CommandKey(addonID: "a", commandID: "work")
        host.register(key: key, entry: jobEntry(inv))
        let gate = await host.prepareJobSpawn(key: key, mode: .replace, programmatic: true)
        XCTAssertEqual(gate, .reuse)
        XCTAssertTrue(inv.process.isRunning)
    }
}
