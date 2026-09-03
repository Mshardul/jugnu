@testable import Jugnu
import JugnuCore
import XCTest

final class RecordingLaunchctl: DaemonLaunchctl {
    var calls: [[String]] = []
    func run(_ arguments: [String]) throws {
        calls.append(arguments)
    }
}

@MainActor
final class DaemonAgentsTests: XCTestCase {
    func test_plistMatchesBlock_andNonAllowlistedRefused() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        let root = home.appendingPathComponent("keep-awake")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: root.appendingPathComponent("bin/watch"), atomically: true, encoding: .utf8)
        let launchctl = RecordingLaunchctl()
        let agents = DaemonAgents(launchctl: launchctl, uid: 501)
        let identity = AddonRunner.ShellIdentity(pid: 9, startTS: 12.5)
        try agents.bootstrap(
            addonID: "keep-awake",
            commandID: "watch",
            block: DaemonBlock(program: "bin/watch", args: ["--loop"], keepAlive: true),
            addonRoot: root,
            paths: paths,
            shellIdentity: identity
        )
        let plist = paths.launchAgentsDir.appendingPathComponent("com.jugnu.keep-awake.watch.plist")
        let text = try String(contentsOf: plist, encoding: .utf8)
        XCTAssertTrue(text.contains("com.jugnu.keep-awake.watch"))
        XCTAssertTrue(text.contains("bin/watch"))
        XCTAssertTrue(text.contains("--loop"))
        XCTAssertTrue(text.contains("JUGNU_ORIGIN"))
        XCTAssertTrue(text.contains("12.5"))
        XCTAssertEqual(launchctl.calls.first, ["bootstrap", "gui/501", plist.path])

        XCTAssertThrowsError(
            try agents.bootstrap(
                addonID: "evil",
                commandID: "watch",
                block: DaemonBlock(program: "bin/watch"),
                addonRoot: root,
                paths: paths,
                shellIdentity: identity
            )
        ) { error in
            XCTAssertEqual(error as? DaemonAgentsError, .notFirstParty("evil"))
        }
    }

    func test_bootoutRemovesPlist() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        let launchctl = RecordingLaunchctl()
        let agents = DaemonAgents(launchctl: launchctl, uid: 501)
        try FileManager.default.createDirectory(at: paths.launchAgentsDir, withIntermediateDirectories: true)
        let plist = paths.launchAgentsDir.appendingPathComponent("com.jugnu.keep-awake.watch.plist")
        try "x".write(to: plist, atomically: true, encoding: .utf8)
        agents.bootout(addonID: "keep-awake", commandID: "watch", paths: paths)
        XCTAssertFalse(FileManager.default.fileExists(atPath: plist.path))
        XCTAssertEqual(launchctl.calls.first?.first, "bootout")
    }
}

@MainActor
final class DisableWhileTrackedTests: XCTestCase {
    func test_disableWhileTracked_promptsAndKills() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("JugnuCoreTests/Fixtures/misbehaving")
        let inv = try AddonRunner().spawn(
            addonRoot: root,
            entrypoint: Entrypoint(kind: "exec", path: "sleep-forever"),
            request: RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:]),
            markerDir: dir
        )
        defer { inv.killImmediately() }
        let host = AddonProcessHost()
        let key = CommandKey(addonID: "toy", commandID: "run")
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
        var prompted = false
        let ok = DisableWhileTracked.proceed(addonID: "toy", host: host) { _ in
            prompted = true
            return true
        }
        XCTAssertTrue(ok)
        XCTAssertTrue(prompted)
        let deadline = Date().addingTimeInterval(3)
        while inv.process.isRunning, Date() < deadline {
            usleep(20_000)
        }
        XCTAssertFalse(inv.process.isRunning)
    }

    func test_disableWhileTracked_rejectCancels() throws {
        let host = AddonProcessHost()
        XCTAssertTrue(DisableWhileTracked.proceed(addonID: "toy", host: host) { _ in true })
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("JugnuCoreTests/Fixtures/misbehaving")
        let inv = try AddonRunner().spawn(
            addonRoot: root,
            entrypoint: Entrypoint(kind: "exec", path: "sleep-forever"),
            request: RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:]),
            markerDir: dir
        )
        defer { inv.killImmediately() }
        host.register(
            key: CommandKey(addonID: "toy", commandID: "run"),
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
        let ok = DisableWhileTracked.proceed(addonID: "toy", host: host) { _ in false }
        XCTAssertFalse(ok)
        XCTAssertTrue(inv.process.isRunning)
    }
}
