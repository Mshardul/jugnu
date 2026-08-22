import CryptoKit
import XCTest
@testable import JugnuCore

final class AddonInstallerTests: XCTestCase {
    func testInstallFromLocalZipAndRejectBadHash() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let fixtureRoot = try XCTUnwrap(
            Bundle.module.url(forResource: "addon", withExtension: "yaml", subdirectory: "Fixtures/echo-addon")?
                .deletingLastPathComponent()
        )
        let staging = home.appendingPathComponent("staging/echo-addon")
        try FileManager.default.createDirectory(
            at: staging.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try copyTree(from: fixtureRoot, to: staging)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: staging.appendingPathComponent("bin/run").path
        )

        let zipURL = home.appendingPathComponent("echo-addon.zip")
        try zipDirectory(staging, to: zipURL)
        let data = try Data(contentsOf: zipURL)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        let paths = JugnuPaths(home: home)
        let installer = AddonInstaller(paths: paths)
        try installer.installFromLocalZip(url: zipURL, expectedSHA256: digest, enable: true)

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: paths.addonsDir.appendingPathComponent("echo-addon/addon.yaml").path
            )
        )
        let config = try ConfigStore(paths: paths).load()
        XCTAssertEqual(config.addons["echo-addon"]?.enabled, true)

        XCTAssertThrowsError(
            try installer.installFromLocalZip(url: zipURL, expectedSHA256: "deadbeef", enable: false)
        ) { error in
            guard case AddonInstallerError.sha256Mismatch = error else {
                return XCTFail("expected sha256Mismatch, got \(error)")
            }
        }
    }

    private func copyTree(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        for child in try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) {
            let target = dst.appendingPathComponent(child.lastPathComponent)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                try copyTree(from: child, to: target)
            } else {
                try fm.copyItem(at: child, to: target)
            }
        }
    }

    private func zipDirectory(_ dir: URL, to zipURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = dir.deletingLastPathComponent()
        process.arguments = ["-qr", zipURL.path, dir.lastPathComponent]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
