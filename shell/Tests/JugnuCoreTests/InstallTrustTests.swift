@testable import JugnuCore
import XCTest

final class InstallHostAllowlistTests: XCTestCase {
    func testAllowsGitHubHTTPS() throws {
        XCTAssertTrue(
            try InstallHostAllowlist
                .isAllowed(XCTUnwrap(URL(string: "https://github.com/org/repo/releases/download/v1/a.zip")))
        )
        XCTAssertTrue(
            try InstallHostAllowlist.isAllowed(
                XCTUnwrap(URL(string: "https://objects.githubusercontent.com/github-production-release-asset/1"))
            )
        )
        XCTAssertTrue(
            try InstallHostAllowlist.isAllowed(
                XCTUnwrap(
                    URL(string: "https://release-assets.githubusercontent.com/github-production-release-asset/1")
                )
            )
        )
        XCTAssertTrue(
            try InstallHostAllowlist.isAllowed(
                XCTUnwrap(
                    URL(string: "https://github-releases.githubusercontent.com/github-production-release-asset/1")
                )
            )
        )
    }

    func testDownloadRejectsNonSuccessHTTPStatus() throws {
        let url = try XCTUnwrap(URL(string: "https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0/x.zip"))
        let redirect = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil))
        XCTAssertThrowsError(try AllowlistedDownloadSession.requireSuccess(redirect)) {
            XCTAssertEqual($0 as? AddonInstallerError, .downloadFailed)
        }
        let ok = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        XCTAssertNoThrow(try AllowlistedDownloadSession.requireSuccess(ok))
    }

    func testRejectsFileAndForeignHosts() throws {
        XCTAssertFalse(try InstallHostAllowlist.isAllowed(XCTUnwrap(URL(string: "file:///tmp/a.zip"))))
        XCTAssertFalse(try InstallHostAllowlist.isAllowed(XCTUnwrap(URL(string: "http://github.com/a.zip"))))
        XCTAssertFalse(try InstallHostAllowlist.isAllowed(XCTUnwrap(URL(string: "https://evil.example/a.zip"))))
    }

    func testRedirectPolicyMatchesAllowlist() throws {
        XCTAssertTrue(try InstallHostAllowlist.isAllowed(XCTUnwrap(URL(string: "https://GITHUB.com/x"))))
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
        try Data([0x50, 0x4B, 0x05, 0x06] + Data(count: 18)).write(to: emptyZip)

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
