@testable import Jugnu
import JugnuCore
import XCTest

@MainActor
final class AddonReaperTests: XCTestCase {
    private func fixtureRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("JugnuCoreTests/Fixtures/misbehaving")
    }

    private func spawnSleeper(_ dir: URL) throws -> RunningInvocation {
        try AddonRunner().spawn(
            addonRoot: fixtureRoot(),
            entrypoint: Entrypoint(kind: "exec", path: "sleep-forever"),
            request: RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:]),
            markerDir: dir
        )
    }

    private func home() throws -> (JugnuPaths, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (JugnuPaths(home: root), root)
    }

    func test_missingDir_isNoOp() throws {
        let (paths, _) = try home()
        let reaper = AddonReaper(paths: paths, killGraceMs: 0)
        reaper.reap(mode: .normal)
    }

    func test_garbageMarker_deleted() throws {
        let (paths, _) = try home()
        try FileManager.default.createDirectory(at: paths.stateRunDir, withIntermediateDirectories: true)
        let junk = paths.stateRunDir.appendingPathComponent("12.json")
        try "not-json".write(to: junk, atomically: true, encoding: .utf8)
        AddonReaper(paths: paths, killGraceMs: 0).reap(mode: .normal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: junk.path))
    }

    func test_staleDeadPid_deleted() throws {
        let (paths, _) = try home()
        try FileManager.default.createDirectory(at: paths.stateRunDir, withIntermediateDirectories: true)
        let marker = RunMarker(origin: "a:b:c", lifecycleClass: "oneshot", shellPID: 1, shellStartTS: 1, spawnedAt: 1)
        try RunMarker.write(marker, pid: 1_000_000, to: paths.stateRunDir)
        AddonReaper(paths: paths, killGraceMs: 0).reap(mode: .normal)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: paths.stateRunDir.appendingPathComponent("1000000.json").path)
        )
    }

    func test_orphanKilled_whenOwnerShellGone() throws {
        let (paths, _) = try home()
        let runDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: runDir) }
        let inv = try spawnSleeper(runDir)
        defer { inv.killImmediately() }
        let pid = inv.process.processIdentifier
        let marker = RunMarker(
            origin: "toy:run:x",
            lifecycleClass: "oneshot",
            shellPID: 9,
            shellStartTS: 1,
            spawnedAt: Date().timeIntervalSince1970
        )
        try RunMarker.write(marker, pid: pid, to: paths.stateRunDir)
        var probe = ProcessProbe.live
        probe.isAlive = { kill($0, 0) == 0 }
        probe.commName = { $0 == pid ? "sleep" : nil }
        probe.startTS = { _ in nil }
        let reaper = AddonReaper(paths: paths, probe: probe, killGraceMs: 0)
        reaper.reap(mode: .normal)
        let deadline = Date().addingTimeInterval(2)
        while inv.process.isRunning, Date() < deadline {
            usleep(20_000)
        }
        XCTAssertFalse(inv.process.isRunning)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: paths.stateRunDir.appendingPathComponent("\(pid).json").path)
        )
    }

    func test_sparesWhenOwnerJugnuStillLive() throws {
        let (paths, _) = try home()
        let runDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: runDir) }
        let inv = try spawnSleeper(runDir)
        defer { inv.killImmediately() }
        let pid = inv.process.processIdentifier
        let marker = RunMarker(
            origin: "toy:run:x",
            lifecycleClass: "oneshot",
            shellPID: 42,
            shellStartTS: 99,
            spawnedAt: 0
        )
        try RunMarker.write(marker, pid: pid, to: paths.stateRunDir)
        var probe = ProcessProbe.live
        probe.commName = { $0 == 42 ? "Jugnu" : "sleep" }
        probe.startTS = { $0 == 42 ? 99 : 0 }
        probe.isAlive = { kill($0, 0) == 0 || $0 == 42 }
        let reaper = AddonReaper(paths: paths, probe: probe, killGraceMs: 0)
        reaper.reap(mode: .normal)
        XCTAssertTrue(inv.process.isRunning)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: paths.stateRunDir.appendingPathComponent("\(pid).json").path)
        )
    }

    func test_pidReuseOfShell_stillKillsOrphan() throws {
        let (paths, _) = try home()
        let runDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: runDir) }
        let inv = try spawnSleeper(runDir)
        defer { inv.killImmediately() }
        let pid = inv.process.processIdentifier
        let marker = RunMarker(
            origin: "toy:run:x",
            lifecycleClass: "oneshot",
            shellPID: pid,
            shellStartTS: 1,
            spawnedAt: 0
        )
        try RunMarker.write(marker, pid: pid, to: paths.stateRunDir)
        var probe = ProcessProbe.live
        probe.commName = { _ in "sleep" }
        probe.startTS = { _ in 999 }
        let reaper = AddonReaper(paths: paths, probe: probe, killGraceMs: 0)
        reaper.reap(mode: .normal)
        let deadline = Date().addingTimeInterval(2)
        while inv.process.isRunning, Date() < deadline {
            usleep(20_000)
        }
        XCTAssertFalse(inv.process.isRunning)
    }

    func test_hostOwnedPid_notKilled() throws {
        let (paths, _) = try home()
        let runDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: runDir) }
        let inv = try spawnSleeper(runDir)
        defer { inv.killImmediately() }
        let pid = inv.process.processIdentifier
        let host = AddonProcessHost()
        host.register(
            key: CommandKey(addonID: "a", commandID: "b"),
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
        let marker = RunMarker(
            origin: "a:b:c",
            lifecycleClass: "oneshot",
            shellPID: 8,
            shellStartTS: 1,
            spawnedAt: 0
        )
        try RunMarker.write(marker, pid: pid, to: paths.stateRunDir)
        var probe = ProcessProbe.live
        probe.commName = { _ in "sleep" }
        probe.startTS = { _ in nil }
        let reaper = AddonReaper(paths: paths, host: host, probe: probe, killGraceMs: 0)
        reaper.reap(mode: .normal)
        XCTAssertTrue(inv.process.isRunning)
    }

    func test_degraded_killsWithoutHost() throws {
        let (paths, _) = try home()
        let runDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: runDir) }
        let inv = try spawnSleeper(runDir)
        defer { inv.killImmediately() }
        let pid = inv.process.processIdentifier
        try RunMarker.write(
            RunMarker(origin: "a:b:c", lifecycleClass: "job", shellPID: 3, shellStartTS: 1, spawnedAt: 0),
            pid: pid,
            to: paths.stateRunDir
        )
        var probe = ProcessProbe.live
        probe.commName = { _ in "sleep" }
        probe.startTS = { _ in nil }
        AddonReaper(paths: paths, probe: probe, killGraceMs: 0).reap(mode: .degraded)
        let deadline = Date().addingTimeInterval(2)
        while inv.process.isRunning, Date() < deadline {
            usleep(20_000)
        }
        XCTAssertFalse(inv.process.isRunning)
    }
}
