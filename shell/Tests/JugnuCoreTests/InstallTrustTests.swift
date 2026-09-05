@testable import JugnuCore
import XCTest

final class InstallHostAllowlistTests: XCTestCase {
    func testAllowsGitHubHTTPS() {
        XCTAssertTrue(
            InstallHostAllowlist.isAllowed(URL(string: "https://github.com/org/repo/releases/download/v1/a.zip")!)
        )
        XCTAssertTrue(
            InstallHostAllowlist.isAllowed(
                URL(string: "https://objects.githubusercontent.com/github-production-release-asset/1")!
            )
        )
    }

    func testRejectsFileAndForeignHosts() {
        XCTAssertFalse(InstallHostAllowlist.isAllowed(URL(string: "file:///tmp/a.zip")!))
        XCTAssertFalse(InstallHostAllowlist.isAllowed(URL(string: "http://github.com/a.zip")!))
        XCTAssertFalse(InstallHostAllowlist.isAllowed(URL(string: "https://evil.example/a.zip")!))
    }

    func testRedirectPolicyMatchesAllowlist() {
        XCTAssertTrue(InstallHostAllowlist.isAllowed(URL(string: "https://GITHUB.com/x")!))
    }
}

final class ZipExtractorPathTests: XCTestCase {
    func testRejectsDotDotAndAbsolutePaths() {
        let dest = URL(fileURLWithPath: "/tmp/jugnu-extract-test")
        XCTAssertThrowsError(try ZipExtractor.validateEntryPath("../etc/passwd", destination: dest)) { error in
            XCTAssertEqual(error as? AddonInstallerError, .unsafeArchive)
        }
        XCTAssertThrowsError(try ZipExtractor.validateEntryPath("/etc/passwd", destination: dest)) { error in
            XCTAssertEqual(error as? AddonInstallerError, .unsafeArchive)
        }
        XCTAssertThrowsError(try ZipExtractor.validateEntryPath("foo\\..\\bar", destination: dest)) { error in
            XCTAssertEqual(error as? AddonInstallerError, .unsafeArchive)
        }
        XCTAssertNoThrow(try ZipExtractor.validateEntryPath("addon.yaml", destination: dest))
        XCTAssertNoThrow(try ZipExtractor.validateEntryPath("bin/run", destination: dest))
    }
}

final class Sha256RequiredTests: XCTestCase {
    func testInstallFromLocalZipRequiresHash() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let emptyZip = home.appendingPathComponent("empty.zip")
        // Minimal invalid zip is fine — hash check runs first.
        try Data([0x50, 0x4b, 0x05, 0x06] + Data(count: 18)).write(to: emptyZip)

        let installer = AddonInstaller(paths: JugnuPaths(home: home))
        XCTAssertThrowsError(try installer.installFromLocalZip(url: emptyZip, expectedSHA256: nil, enable: false)) {
            XCTAssertEqual($0 as? AddonInstallerError, .sha256Required)
        }
        XCTAssertThrowsError(try installer.installFromLocalZip(url: emptyZip, expectedSHA256: "", enable: false)) {
            XCTAssertEqual($0 as? AddonInstallerError, .sha256Required)
        }
        XCTAssertThrowsError(
            try installer.installHelperFromLocalZip(
                url: emptyZip,
                expectedSHA256: nil,
                id: "clock",
                version: "1.0.0"
            )
        ) {
            XCTAssertEqual($0 as? AddonInstallerError, .sha256Required)
        }
    }
}
