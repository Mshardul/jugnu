import XCTest
@testable import JugnuCore

final class AddonRunnerTests: XCTestCase {
    func testRunsEchoFixture() throws {
        let bundleRoot = try XCTUnwrap(
            Bundle.module.url(forResource: "addon", withExtension: "yaml", subdirectory: "Fixtures/echo-addon")?
                .deletingLastPathComponent()
        )
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        try copyTree(from: bundleRoot, to: work)
        let runURL = work.appendingPathComponent("bin/run")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runURL.path)

        let manifest = try ManifestLoader.load(from: work)
        let response = try AddonRunner(timeoutSeconds: 2).run(manifest: manifest, addonRoot: work, commandId: "ping")
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.message, "echo-ok")
    }

    func testRunnerDecodesListUI() throws {
        let root = try copyUIHostFixtures()
        defer { try? FileManager.default.removeItem(at: root) }
        let entry = Entrypoint(kind: "exec", path: "echo-list.sh")
        let req = RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:])
        let res = try AddonRunner(timeoutSeconds: 2).run(
            addonRoot: root,
            entrypoint: entry,
            request: req,
            timeout: 2
        )
        XCTAssertEqual(res.ui?.pattern, .list)
        XCTAssertEqual(res.ui?.items?.first?.id, "a")
    }

    private func copyUIHostFixtures() throws -> URL {
        let bundleRoot = try XCTUnwrap(
            Bundle.module.url(forResource: "echo-list", withExtension: "sh", subdirectory: "Fixtures/ui-host")?
                .deletingLastPathComponent()
        )
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try copyTree(from: bundleRoot, to: work)
        for name in ["echo-list.sh", "echo-toast.sh", "echo-confirm.sh", "echo-form.sh"] {
            let url = work.appendingPathComponent(name)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        return work
    }

    private func copyTree(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        let children = try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
        for child in children {
            let target = dst.appendingPathComponent(child.lastPathComponent)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                try copyTree(from: child, to: target)
            } else {
                try fm.copyItem(at: child, to: target)
            }
        }
    }
}
