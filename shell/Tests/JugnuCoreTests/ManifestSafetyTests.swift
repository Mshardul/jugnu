@testable import JugnuCore
import XCTest

final class ManifestSafetyTests: XCTestCase {
    private func writeManifest(_ yaml: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        return dir
    }

    private func manifest(id: String = "jugnu.demo", extra: String = "", entry: String = "bin/run") -> String {
        """
        id: \(id)
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: run
            title: Run
        entrypoint:
          kind: exec
          path: \(entry)
        \(extra)
        """
    }

    private func assertUnsafe(_ yaml: String, field: String, file: StaticString = #filePath,
                              line: UInt = #line) throws
    {
        let dir = try writeManifest(yaml)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir), file: file, line: line) { error in
            XCTAssertEqual(error as? ManifestLoaderError, .unsafeManifestField(field), file: file, line: line)
        }
    }

    func testRejectsTraversingHelperRef() throws {
        try assertUnsafe(manifest(extra: "helpers:\n  - id: \"..\"\n    version: 1.0.0"), field: "helpers.id")
        try assertUnsafe(manifest(extra: "helpers:\n  - id: clock\n    version: \"..\""), field: "helpers.version")
    }

    func testRejectsEntrypointOutsideAddonRoot() throws {
        try assertUnsafe(manifest(entry: "../../bin/sh"), field: "entrypoint.path")
        try assertUnsafe(manifest(entry: "/bin/sh"), field: "entrypoint.path")
    }

    func testRejectsCleanupPathsOutsideOwnState() throws {
        for bad in ["~", "~/Documents", "/", "~/.local/share/jugnu/state/jugnu.other",
                    "~/.local/share/jugnu/state/demo/../../..", "~/.local/share/jugnu/state/"]
        {
            try assertUnsafe(
                manifest(extra: "cleanup:\n  paths:\n    - \"\(bad)\"\n  launchd: []"),
                field: "cleanup.paths"
            )
        }
    }

    func testAcceptsCleanupPathsInOwnState() throws {
        let yaml = manifest(extra: """
        cleanup:
          paths:
            - "~/.local/share/jugnu/state/demo"
            - "~/.local/share/jugnu/state/jugnu.demo/cache"
            - "~/.config/jugnu/addons/demo"
          launchd: []
        """)
        XCTAssertNoThrow(try ManifestLoader.load(from: writeManifest(yaml)))
    }

    func testRejectsCleanupLaunchdLabelsOutsideOwnNamespace() throws {
        for bad in ["com.apple.something", "com.jugnu.other.watch", "com.jugnu.demo.../../x", "../../x"] {
            try assertUnsafe(
                manifest(extra: "cleanup:\n  paths: []\n  launchd:\n    - \"\(bad)\""),
                field: "cleanup.launchd"
            )
        }
        XCTAssertNoThrow(
            try ManifestLoader
                .load(
                    from: writeManifest(
                        manifest(extra: "cleanup:\n  paths: []\n  launchd:\n    - com.jugnu.demo.watch")
                    )
                )
        )
    }
}
