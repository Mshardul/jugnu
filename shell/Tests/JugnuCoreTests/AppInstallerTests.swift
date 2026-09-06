@testable import JugnuCore
import CryptoKit
import XCTest

final class AppInstallerTests: XCTestCase {
    func testRecoverClearsAppUpdateStaging() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        let orphan = paths.appUpdateStagingDir.appendingPathComponent("leftover")
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)
        try "x".write(to: orphan.appendingPathComponent("marker"), atomically: true, encoding: .utf8)

        AddonInstaller(paths: paths).recoverInstallOrphans()

        let leftover = try FileManager.default.contentsOfDirectory(
            at: paths.appUpdateStagingDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        XCTAssertTrue(leftover.isEmpty)
    }

    func testStageRejectsSha256Mismatch() async throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let zip = try makeAppZip(in: home, version: "0.2.0")
        let installer = AppInstaller(paths: JugnuPaths(home: home), downloads: TestFileDownloader())
        do {
            _ = try await installer.stage(entry: entry(url: zip, sha256: "deadbeef", version: "0.2.0"))
            XCTFail("expected sha256Mismatch")
        } catch let error as AddonInstallerError {
            guard case .sha256Mismatch = error else {
                return XCTFail("expected sha256Mismatch, got \(error)")
            }
        }
    }

    func testStageRejectsZipSlip() async throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let zip = home.appendingPathComponent("slip.zip")
        try writeSlipZip(to: zip)
        let digest = try sha256(of: zip)
        let paths = JugnuPaths(home: home)
        let installer = AppInstaller(paths: paths, downloads: TestFileDownloader())
        do {
            _ = try await installer.stage(entry: entry(url: zip, sha256: digest, version: "0.2.0"))
            XCTFail("expected unsafeArchive")
        } catch let error as AddonInstallerError {
            XCTAssertEqual(error, .unsafeArchive)
        }
        let leftover = try FileManager.default.contentsOfDirectory(
            at: paths.appUpdateStagingDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        XCTAssertTrue(leftover.isEmpty)
    }

    func testStageRejectsVersionMismatchAfterExtract() async throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let zip = try makeAppZip(in: home, version: "0.1.0")
        let digest = try sha256(of: zip)
        let paths = JugnuPaths(home: home)
        let installer = AppInstaller(paths: paths, downloads: TestFileDownloader())
        do {
            _ = try await installer.stage(entry: entry(url: zip, sha256: digest, version: "0.2.0"))
            XCTFail("expected versionMismatch")
        } catch let error as AppUpdateError {
            XCTAssertEqual(error, .versionMismatch(expected: "0.2.0", actual: "0.1.0"))
        }
        let leftover = try FileManager.default.contentsOfDirectory(
            at: paths.appUpdateStagingDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        XCTAssertTrue(leftover.isEmpty)
    }

    func testStageExtractsVerifiedApp() async throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let zip = try makeAppZip(in: home, version: "0.2.0")
        let digest = try sha256(of: zip)
        let installer = AppInstaller(paths: JugnuPaths(home: home), downloads: TestFileDownloader())
        let staged = try await installer.stage(entry: entry(url: zip, sha256: digest, version: "0.2.0"))
        XCTAssertEqual(staged.lastPathComponent, "Jugnu.app")
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.appendingPathComponent("Contents/Info.plist").path))
    }
}

private func scratch() throws -> URL {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    return home
}

private func entry(url: URL, sha256: String, version: String) -> AppRegistryEntry {
    AppRegistryEntry(
        id: "jugnu.shell",
        name: "Jugnu",
        version: version,
        minMacOS: "14.0",
        url: url.absoluteString,
        sha256: sha256
    )
}

private func makeAppZip(in home: URL, version: String) throws -> URL {
    let wrap = home.appendingPathComponent("payload")
    try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
    _ = try writeFakeApp(in: wrap, version: version)
    let zipURL = home.appendingPathComponent("Jugnu-\(version).zip")
    try zipDirectory(wrap, to: zipURL)
    return zipURL
}

@discardableResult
private func writeFakeApp(in parent: URL, version: String) throws -> URL {
    let app = parent.appendingPathComponent("Jugnu.app")
    let macos = app.appendingPathComponent("Contents/MacOS")
    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>CFBundleIdentifier</key>
    <string>app.jugnu.shell</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>\(version)</string>
    <key>CFBundleExecutable</key>
    <string>Jugnu</string>
    </dict>
    </plist>
    """
    try plist.write(
        to: app.appendingPathComponent("Contents/Info.plist"),
        atomically: true,
        encoding: .utf8
    )
    let exec = macos.appendingPathComponent("Jugnu")
    try "#!/bin/sh\necho ok\n".write(to: exec, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exec.path)
    return app
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

private func writeSlipZip(to zipURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = [
        "-c",
        "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w'); z.writestr('../evil.txt','x'); z.close()",
        zipURL.path,
    ]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
}

private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private struct TestFileDownloader: InstallDownloading {
    func download(_ url: URL) async throws -> URL {
        guard url.isFileURL else { throw AddonInstallerError.hostNotAllowed }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-test-\(UUID().uuidString).zip")
        try FileManager.default.copyItem(at: url, to: tmp)
        return tmp
    }
}
