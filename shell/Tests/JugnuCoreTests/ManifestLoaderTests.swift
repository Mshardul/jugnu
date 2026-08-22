import XCTest
@testable import JugnuCore

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
}
