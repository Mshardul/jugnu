@testable import Jugnu
import JugnuCore
import XCTest

@MainActor
final class AddonProcessHostTests: XCTestCase {
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
        let root = fixtureRoot()
        let entry = Entrypoint(kind: "exec", path: "sleep-forever")
        return try AddonRunner().spawn(
            addonRoot: root,
            entrypoint: entry,
            request: RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:]),
            markerDir: dir
        )
    }

    private func makeEntry(_ inv: RunningInvocation, uuid: UUID) -> AddonProcessHost.Entry {
        AddonProcessHost.Entry(
            invocation: inv,
            invocationTask: nil,
            lifecycleClass: .oneshot,
            startedAt: Date(),
            invokeUUID: uuid,
            markerPath: inv.markerURL,
            phase: .live
        )
    }

    func test_register_thenHasTracked_isTrue() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        defer { inv.terminate() }
        let key = CommandKey(addonID: "a", commandID: "b")
        host.register(key: key, entry: makeEntry(inv, uuid: UUID()))
        XCTAssertTrue(host.hasTracked(key: key))
    }

    func test_deregister_byInvokeUUID_removesEntry() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let inv = try spawnSleeper(dir)
        defer { inv.terminate() }
        let key = CommandKey(addonID: "a", commandID: "b")
        let uuid = UUID()
        host.register(key: key, entry: makeEntry(inv, uuid: uuid))
        host.deregister(key: key, invokeUUID: uuid)
        XCTAssertFalse(host.hasTracked(key: key))
    }

    func test_twoEntriesForOneKey_coexist() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let a = try spawnSleeper(dir)
        let b = try spawnSleeper(dir)
        defer { a.terminate(); b.terminate() }
        let key = CommandKey(addonID: "a", commandID: "b")
        host.register(key: key, entry: makeEntry(a, uuid: UUID()))
        host.register(key: key, entry: makeEntry(b, uuid: UUID()))
        XCTAssertEqual(host.tracked().count, 2)
    }

    func test_killAll_marksDyingAndReturnsWithoutAwaiting() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let a = try spawnSleeper(dir)
        let b = try spawnSleeper(dir)
        let key = CommandKey(addonID: "a", commandID: "b")
        host.register(key: key, entry: makeEntry(a, uuid: UUID()))
        host.register(key: key, entry: makeEntry(b, uuid: UUID()))
        let start = Date()
        host.killAll()
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        let deadline = Date().addingTimeInterval(3)
        while a.process.isRunning || b.process.isRunning, Date() < deadline {
            usleep(20000)
        }
        XCTAssertFalse(a.process.isRunning)
        XCTAssertFalse(b.process.isRunning)
    }

    func test_killTracked_perCommandKeyIsolation() throws {
        let dir = markerDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let host = AddonProcessHost()
        let a = try spawnSleeper(dir)
        let b = try spawnSleeper(dir)
        defer { a.terminate(); b.terminate() }
        let keyA = CommandKey(addonID: "a", commandID: "1")
        let keyB = CommandKey(addonID: "b", commandID: "2")
        host.register(key: keyA, entry: makeEntry(a, uuid: UUID()))
        host.register(key: keyB, entry: makeEntry(b, uuid: UUID()))
        host.killTracked(key: keyB)
        XCTAssertTrue(host.hasTracked(key: keyA))
        let deadline = Date().addingTimeInterval(3)
        while b.process.isRunning, Date() < deadline {
            usleep(20000)
        }
        XCTAssertFalse(b.process.isRunning)
        XCTAssertTrue(a.process.isRunning)
    }
}
