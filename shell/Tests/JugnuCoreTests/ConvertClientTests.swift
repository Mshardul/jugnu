@testable import JugnuCore
import XCTest

final class ConvertClientTests: XCTestCase {
    private func stubAddon(reply: String) throws -> (AddonManifest, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("bin"),
            withIntermediateDirectories: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("bin/run")
        try "#!/bin/sh\ncat > \"$(dirname \"$0\")/../request.json\"\nprintf '%s' '\(reply)'\n"
            .write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        try """
        id: jugnu.stub
        name: Stub
        version: 1.0.0
        api: 1
        commands:
          - id: json-csv
            title: JSON to CSV
        entrypoint:
          kind: exec
          path: bin/run
        converters:
          - command: json-csv
            from: json
            to: csv
            modes: [text]
        """.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        return try (ManifestLoader.load(from: dir), dir)
    }

    private func route(_ manifest: AddonManifest) throws -> ConvertRoute {
        try XCTUnwrap(ConvertGraph(manifests: [manifest]).route(from: "json", to: "csv", mode: .text))
    }

    func testSendsConvertRequestAndReturnsText() async throws {
        let (manifest, root) = try stubAddon(reply: #"{"ok":true,"text":"a,b"}"#)
        let out = try await ConvertClient().convertText(
            "[1]", route: route(manifest), manifest: manifest, addonRoot: root
        )
        XCTAssertEqual(out, "a,b")
        let sent = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent("request.json"))
        ) as? [String: Any]
        XCTAssertEqual(sent?["op"] as? String, "convert")
        XCTAssertEqual(sent?["command"] as? String, "json-csv")
        XCTAssertEqual(sent?["from"] as? String, "json")
        XCTAssertEqual(sent?["to"] as? String, "csv")
        XCTAssertEqual(sent?["text"] as? String, "[1]")
    }

    func testAddonErrorSurfacesAsFailure() async throws {
        let (manifest, root) = try stubAddon(reply: #"{"ok":false,"error":"Not valid JSON."}"#)
        do {
            _ = try await ConvertClient().convertText(
                "x", route: route(manifest), manifest: manifest, addonRoot: root
            )
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? ConvertClientError, .failed("Not valid JSON."))
        }
    }

    func testOkWithoutTextIsFailure() async throws {
        let (manifest, root) = try stubAddon(reply: #"{"ok":true}"#)
        do {
            _ = try await ConvertClient().convertText(
                "x", route: route(manifest), manifest: manifest, addonRoot: root
            )
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? ConvertClientError, .failed("Conversion failed."))
        }
    }
}

final class ConvertClientFileTests: XCTestCase {
    private static let writeScript = #"""
    out=$(printf '%s' "$req" | sed -n 's/.*"out":"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g')
    printf converted > "$out"
    printf '%s' '{"ok":true}'
    """#

    private func stub(failWith error: String? = nil) throws -> (AddonManifest, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("bin"),
            withIntermediateDirectories: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("bin/run")
        let body = error.map { "printf '%s' '{\"ok\":false,\"error\":\"\($0)\"}'" } ?? Self.writeScript
        try "#!/bin/sh\nreq=$(cat)\n\(body)\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        try """
        id: jugnu.stub
        name: Stub
        version: 1.0.0
        api: 1
        commands:
          - id: json-csv
            title: JSON to CSV
        entrypoint:
          kind: exec
          path: bin/run
        converters:
          - command: json-csv
            from: json
            to: csv
            modes: [file]
        """.write(to: dir.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        return try (ManifestLoader.load(from: dir), dir)
    }

    private func input() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("data.json")
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testWritesCollisionFreeFileBesideOriginal() async throws {
        let (manifest, root) = try stub()
        let route = try XCTUnwrap(ConvertGraph(manifests: [manifest]).route(from: "json", to: "csv", mode: .file))
        let source = try input()
        let first = try await ConvertClient().convertFile(
            source, outputExtension: "csv", route: route, manifest: manifest, addonRoot: root
        )
        let second = try await ConvertClient().convertFile(
            source, outputExtension: "csv", route: route, manifest: manifest, addonRoot: root
        )
        XCTAssertEqual(first.lastPathComponent, "data.csv")
        XCTAssertEqual(second.lastPathComponent, "data 2.csv")
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "converted")
    }

    func testOutputDirectoryOverridesBesideOriginal() async throws {
        let (manifest, root) = try stub()
        let route = try XCTUnwrap(ConvertGraph(manifests: [manifest]).route(from: "json", to: "csv", mode: .file))
        let source = try input()
        let elsewhere = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: elsewhere) }
        let out = try await ConvertClient().convertFile(
            source, outputExtension: "csv", outputDirectory: elsewhere, route: route, manifest: manifest,
            addonRoot: root
        )
        XCTAssertEqual(out.deletingLastPathComponent().lastPathComponent, elsewhere.lastPathComponent)
        XCTAssertEqual(out.lastPathComponent, "data.csv")
        let beside = try FileManager.default.contentsOfDirectory(atPath: source.deletingLastPathComponent().path)
        XCTAssertEqual(beside, ["data.json"])
    }

    func testFailureRemovesReservedOutput() async throws {
        let (manifest, root) = try stub(failWith: "Bad file.")
        let route = try XCTUnwrap(ConvertGraph(manifests: [manifest]).route(from: "json", to: "csv", mode: .file))
        let source = try input()
        do {
            _ = try await ConvertClient().convertFile(
                source, outputExtension: "csv", route: route, manifest: manifest, addonRoot: root
            )
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? ConvertClientError, .failed("Bad file."))
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: source.deletingLastPathComponent().path)
        XCTAssertEqual(left, ["data.json"])
    }
}
