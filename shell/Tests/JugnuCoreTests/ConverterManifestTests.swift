@testable import JugnuCore
import XCTest

final class ConverterManifestTests: XCTestCase {
    private func writeManifest(_ yaml: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        try yaml.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        return dir
    }

    private func manifest(id: String = "jugnu.demo", extra: String) -> String {
        """
        id: \(id)
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: json-csv
            title: JSON to CSV
          - id: csv-json
            title: CSV to JSON
        entrypoint:
          kind: exec
          path: bin/run
        \(extra)
        """
    }

    func testLoadsConvertersAndFormats() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: json-csv
            from: json
            to: csv
            modes: [text]
          - command: csv-json
            from: csv
            to: json
            modes: [text, file]
        formats:
          - id: ndjson
            label: Newline-delimited JSON
            extensions: [ndjson, jsonl]
            mime: application/x-ndjson
        """))
        let m = try ManifestLoader.load(from: dir)
        XCTAssertEqual(m.converters.count, 2)
        XCTAssertEqual(m.converters[0], ConverterEdge(command: "json-csv", from: "json", to: "csv", modes: [.text]))
        XCTAssertEqual(m.converters[1].modes, [.text, .file])
        XCTAssertEqual(m.formats.first?.id, "ndjson")
        XCTAssertEqual(m.formats.first?.extensions, ["ndjson", "jsonl"])
    }

    func testConvertersDefaultEmpty() throws {
        let m = try ManifestLoader.load(from: writeManifest(manifest(extra: "")))
        XCTAssertEqual(m.converters, [])
        XCTAssertEqual(m.formats, [])
    }

    func testRejectsConverterWithUnknownCommand() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: nope
            from: json
            to: csv
            modes: [text]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .unknownConverterCommand("nope"))
        }
    }

    func testRejectsSameFromAndTo() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: json-csv
            from: json
            to: json
            modes: [text]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidConverter("json-csv"))
        }
    }

    func testRejectsEmptyModes() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: json-csv
            from: json
            to: csv
            modes: []
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidConverter("json-csv"))
        }
    }

    func testRejectsUnknownMode() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: json-csv
            from: json
            to: csv
            modes: [stream]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidConverter("json-csv"))
        }
    }

    func testRejectsMalformedFormatIdInEdge() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: json-csv
            from: JSON
            to: csv
            modes: [text]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidFormat("JSON"))
        }
    }

    func testRejectsDuplicateEdgeInOneAddon() throws {
        let dir = try writeManifest(manifest(extra: """
        converters:
          - command: json-csv
            from: json
            to: csv
            modes: [text]
          - command: csv-json
            from: json
            to: csv
            modes: [text]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidConverter("csv-json"))
        }
    }

    func testRejectsDuplicateFormatDeclaration() throws {
        let dir = try writeManifest(manifest(extra: """
        formats:
          - id: ndjson
            label: A
            extensions: [ndjson]
          - id: ndjson
            label: B
            extensions: [jsonl]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidFormat("ndjson"))
        }
    }

    func testRejectsFormatExtensionWithDotOrUppercase() throws {
        let dir = try writeManifest(manifest(extra: """
        formats:
          - id: ndjson
            label: A
            extensions: [".ndjson"]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidFormat("ndjson"))
        }
    }

    func testRejectsRedefiningCoreFormat() throws {
        let dir = try writeManifest(manifest(extra: """
        formats:
          - id: json
            label: My JSON
            extensions: [json]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidFormat("json"))
        }
    }

    // MARK: shell entrypoint

    private func shellManifest(id: String, extra: String = "") -> String {
        """
        id: \(id)
        name: Convert
        version: 1.0.0
        api: 1
        commands:
          - id: convert-file
            title: Convert a file
        entrypoint:
          kind: shell
        \(extra)
        """
    }

    func testLoadsShellEntrypointWithoutPathForFirstParty() throws {
        let m = try ManifestLoader.load(from: writeManifest(shellManifest(id: "jugnu.convert")))
        XCTAssertEqual(m.entrypoint.kind, "shell")
        XCTAssertEqual(m.entrypoint.path, "")
        XCTAssertTrue(m.entrypoint.isShell)
    }

    func testRejectsShellEntrypointForThirdParty() throws {
        let dir = try writeManifest(shellManifest(id: "acme.convert"))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .shellEntrypointNotFirstParty("acme.convert"))
        }
    }

    func testRejectsConvertersOnShellEntrypoint() throws {
        let dir = try writeManifest(shellManifest(id: "jugnu.convert", extra: """
        converters:
          - command: convert-file
            from: json
            to: csv
            modes: [text]
        """))
        XCTAssertThrowsError(try ManifestLoader.load(from: dir)) {
            XCTAssertEqual($0 as? ManifestLoaderError, .invalidConverter("convert-file"))
        }
    }

    func testExecEntrypointStillRequiresPath() throws {
        let dir = try writeManifest("""
        id: jugnu.demo
        name: Demo
        version: 1.0.0
        api: 1
        commands:
          - id: x
            title: X
        entrypoint:
          kind: exec
        """)
        XCTAssertThrowsError(try ManifestLoader.load(from: dir))
    }
}
