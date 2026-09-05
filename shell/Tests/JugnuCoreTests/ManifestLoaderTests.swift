@testable import JugnuCore
import XCTest

final class ManifestLoaderTests: XCTestCase {
    func testLoadsManifest() throws {
        let root = try XCTUnwrap(
            Bundle.module.url(forResource: "addon", withExtension: "yaml", subdirectory: "Fixtures/mic-mute")?
                .deletingLastPathComponent()
        )
        let m = try ManifestLoader.load(from: root)
        XCTAssertEqual(m.id, "mic-mute")
        XCTAssertEqual(m.api, 1)
        XCTAssertEqual(m.commands.first?.id, "toggle")
        XCTAssertEqual(m.entrypoint.path, "bin/run")
        XCTAssertEqual(m.entrypoint.kind, "exec")
    }

    func testLoadsCommandUIPattern() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let yaml = """
        id: demo
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: demo
            title: Demo list
            ui:
              pattern: list
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertEqual(m.commands.first?.defaultUIPattern, .list)
    }

    func testRejectsUnsupportedAPI() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let yaml = """
        id: bad
        name: Bad
        version: 1.0.0
        api: 99
        commands: []
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .unsupportedAPI(99))
        }
    }

    func testLoadsViewTypesAllowList() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let yaml = """
        id: demo
        name: Demo
        version: 1.0.0
        api: 1
        view_types: [board, rows]
        commands:
          - id: board
            title: Snap board
            view: board
            ui:
              pattern: list
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertEqual(m.viewTypes, [.board, .rows])
        XCTAssertEqual(m.commands.first?.view, .board)
    }

    func testRejectsUnknownViewType() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let yaml = """
        id: bad
        name: Bad
        version: 1.0.0
        api: 1
        view_types: [wall]
        commands:
          - id: x
            title: X
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .unknownViewType("wall"))
        }
    }

    func testRejectsCommandViewOutsideAllowList() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let yaml = """
        id: bad
        name: Bad
        version: 1.0.0
        api: 1
        commands:
          - id: x
            title: X
            view: board
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .commandViewNotAllowed(command: "x", view: "board"))
        }
    }

    func testLoadsDeclaredHelpers() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let yaml = """
        id: dice-roll
        name: Dice Roll
        version: 1.0.0
        api: 1
        helpers:
          - id: play-runtime
            version: 1.0.0
        commands:
          - id: roll
            title: Roll
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertEqual(m.helpers, [HelperRef(id: "play-runtime", version: "1.0.0")])
        XCTAssertEqual(m.helpers[0].environmentVariable, "JUGNU_HELPER_PLAY_RUNTIME")
    }

    func testOmitsHelpersWhenAbsent() throws {
        let root = try XCTUnwrap(
            Bundle.module.url(forResource: "addon", withExtension: "yaml", subdirectory: "Fixtures/mic-mute")?
                .deletingLastPathComponent()
        )
        let m = try ManifestLoader.load(from: root)
        XCTAssertEqual(m.helpers, [])
    }

    private func writeManifest(_ yaml: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        return dir
    }

    func testLifecycleOmittedResolvesToOneshot() throws {
        let dir = try writeManifest("""
        id: demo
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: go
            title: Go
        entrypoint:
          kind: exec
          path: bin/run
        """)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertNil(m.lifecycle)
        XCTAssertNil(m.commands.first?.lifecycle)
        XCTAssertEqual(m.effectiveLifecycle(commandId: "go"), .oneshot)
    }

    func testCommandLifecycleOverridesRoot() throws {
        let dir = try writeManifest("""
        id: demo
        name: Demo
        version: 1.0.0
        api: 1
        lifecycle: job
        commands:
          - id: watch
            title: Watch
          - id: once
            title: Once
            lifecycle: oneshot
        entrypoint:
          kind: exec
          path: bin/run
        """)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertEqual(m.lifecycle, .job)
        XCTAssertEqual(m.effectiveLifecycle(commandId: "watch"), .job)
        XCTAssertEqual(m.effectiveLifecycle(commandId: "once"), .oneshot)
    }

    func testSessionLifecycleThrowsTypedError() throws {
        let dir = try writeManifest("""
        id: demo
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: go
            title: Go
            lifecycle: session
        entrypoint:
          kind: exec
          path: bin/run
        """)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .sessionNotSupported)
        }
    }

    func testDaemonBlockParsesAndOnReinvokeDefaults() throws {
        let dir = try writeManifest("""
        id: jugnu.keep-awake
        name: Keep Awake
        version: 1.0.0
        api: 1
        commands:
          - id: watch
            title: Watch
            lifecycle: daemon
            on_reinvoke: replace
            timeout: 5
            daemon:
              program: bin/watcher
              args: ["--loop"]
              keep_alive: true
        entrypoint:
          kind: exec
          path: bin/run
        """)
        let m = try ManifestLoader.load(from: dir)
        let cmd = try XCTUnwrap(m.commands.first)
        XCTAssertEqual(cmd.daemon, DaemonBlock(program: "bin/watcher", args: ["--loop"], keepAlive: true))
        XCTAssertEqual(cmd.onReinvoke, .replace)
        XCTAssertEqual(cmd.timeout, 5)
    }

    func testOnReinvokeDefaultIsNilAndReadsReuse() throws {
        let dir = try writeManifest("""
        id: demo
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: a
            title: A
          - id: b
            title: B
            on_reinvoke: reuse
        entrypoint:
          kind: exec
          path: bin/run
        """)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertNil(m.commands[0].onReinvoke)
        XCTAssertEqual(m.commands[1].onReinvoke, .reuse)
    }

    func testDaemonCommandWithoutBlockIsRejected() throws {
        let dir = try writeManifest("""
        id: jugnu.keep-awake
        name: Keep Awake
        version: 1.0.0
        api: 1
        commands:
          - id: watch
            title: Watch
            lifecycle: daemon
        entrypoint:
          kind: exec
          path: bin/run
        """)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .daemonBlockMissing(command: "watch"))
        }
    }

    func testDaemonNotFirstPartyIsRejected() throws {
        let dir = try writeManifest("""
        id: evil-daemon
        name: Evil
        version: 1.0.0
        api: 1
        commands:
          - id: watch
            title: Watch
            lifecycle: daemon
            daemon:
              program: bin/watch
        entrypoint:
          kind: exec
          path: bin/run
        """)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .daemonNotFirstParty("evil-daemon"))
        }
    }

    func testEffectiveCleanupLaunchdIncludesDaemonLabels() throws {
        let dir = try writeManifest("""
        id: jugnu.keep-awake
        name: Keep Awake
        version: 1.0.0
        api: 1
        commands:
          - id: watch
            title: Watch
            lifecycle: daemon
            daemon:
              program: bin/watch
        entrypoint:
          kind: exec
          path: bin/run
        cleanup:
          paths: []
          launchd: []
        """)
        let m = try ManifestLoader.load(from: dir)
        XCTAssertEqual(m.effectiveCleanupLaunchd(), ["com.jugnu.keep-awake.watch"])
        XCTAssertEqual(m.effectiveOnReinvoke(commandId: "watch"), .reuse)
    }
}
