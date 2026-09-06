@testable import JugnuCore
import XCTest

final class AppPackageTests: XCTestCase {
    func testFindAppBundleAtExtractRoot() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(in: root, version: "0.2.0")
        XCTAssertEqual(try AppPackage.findAppBundle(in: root).path, app.path)
    }

    func testFindAppBundleInSingleChildDirectory() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let wrap = root.appendingPathComponent("Jugnu-0.2.0")
        try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
        let app = try makeFakeApp(in: wrap, version: "0.2.0")
        XCTAssertEqual(
            try AppPackage.findAppBundle(in: root).standardizedFileURL.path,
            app.standardizedFileURL.path
        )
    }

    func testFindAppBundleRejectsMultipleRoots() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a")
        let b = root.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        _ = try makeFakeApp(in: a, version: "0.2.0")
        _ = try makeFakeApp(in: b, version: "0.2.0")
        XCTAssertThrowsError(try AppPackage.findAppBundle(in: root)) { error in
            XCTAssertEqual(error as? AppUpdateError, .bundleIdentity)
        }
    }

    func testFindAppBundleRejectsMissingApp() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AppPackage.findAppBundle(in: root)) { error in
            XCTAssertEqual(error as? AppUpdateError, .bundleIdentity)
        }
    }

    func testCheckRejectsWrongBundleId() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(in: root, version: "0.2.0", bundleId: "com.example.not-jugnu")
        XCTAssertThrowsError(try AppPackage.check(bundle: app, expectedVersion: "0.2.0")) { error in
            XCTAssertEqual(error as? AppUpdateError, .bundleIdentity)
        }
    }

    func testCheckRejectsWrongPackageType() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(in: root, version: "0.2.0", packageType: "BNDL")
        XCTAssertThrowsError(try AppPackage.check(bundle: app, expectedVersion: "0.2.0")) { error in
            XCTAssertEqual(error as? AppUpdateError, .bundleIdentity)
        }
    }

    func testCheckRejectsVersionMismatch() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(in: root, version: "0.1.0")
        XCTAssertThrowsError(try AppPackage.check(bundle: app, expectedVersion: "0.2.0")) { error in
            XCTAssertEqual(
                error as? AppUpdateError,
                .versionMismatch(expected: "0.2.0", actual: "0.1.0")
            )
        }
    }

    func testCheckAcceptsShebangExecutable() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(in: root, version: "0.2.0")
        XCTAssertNoThrow(try AppPackage.check(bundle: app, expectedVersion: "0.2.0"))
    }

    func testCheckAcceptsMissingPackageType() throws {
        let root = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(in: root, version: "0.2.0", packageType: nil)
        XCTAssertNoThrow(try AppPackage.check(bundle: app, expectedVersion: "0.2.0"))
    }
}

private func scratch() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@discardableResult
private func makeFakeApp(
    in parent: URL,
    version: String,
    bundleId: String = "app.jugnu.shell",
    packageType: String? = "APPL"
) throws -> URL {
    let app = parent.appendingPathComponent("Jugnu.app")
    let macos = app.appendingPathComponent("Contents/MacOS")
    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    var keys = """
    <key>CFBundleIdentifier</key>
    <string>\(bundleId)</string>
    <key>CFBundleShortVersionString</key>
    <string>\(version)</string>
    <key>CFBundleExecutable</key>
    <string>Jugnu</string>
    """
    if let packageType {
        keys += """

        <key>CFBundlePackageType</key>
        <string>\(packageType)</string>
        """
    }
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \(keys)
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
