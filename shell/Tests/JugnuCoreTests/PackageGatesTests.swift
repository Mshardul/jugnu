@testable import JugnuCore
import XCTest

final class PackageGatesTests: XCTestCase {
    func testSemVerCompare() {
        XCTAssertEqual(PackageGates.compareSemVer("0.1.0", "0.2.0"), .orderedAscending)
        XCTAssertEqual(PackageGates.compareSemVer("1.0.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(PackageGates.compareSemVer("2.0.0", "1.9.9"), .orderedDescending)
    }

    func testMinShellVersionInstallGate() {
        XCTAssertNoThrow(try PackageGates.checkMinShellVersion(required: nil, running: "0.1.0"))
        XCTAssertNoThrow(try PackageGates.checkMinShellVersion(required: "0.1.0", running: "0.1.0"))
        XCTAssertThrowsError(try PackageGates.checkMinShellVersion(required: "0.2.0", running: "0.1.0")) {
            guard case AddonInstallerError.shellTooOld(let required, let running) = $0 else {
                return XCTFail("got \($0)")
            }
            XCTAssertEqual(required, "0.2.0")
            XCTAssertEqual(running, "0.1.0")
        }
        XCTAssertFalse(PackageGates.isRunnable(minShellVersion: "9.0.0", running: "0.1.0"))
        XCTAssertTrue(PackageGates.isRunnable(minShellVersion: nil, running: "0.1.0"))
    }

    func testShebangEntrypointPasses() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("run")
        try "#!/bin/sh\necho ok\n".write(to: script, atomically: true, encoding: .utf8)
        XCTAssertNoThrow(try PackageGates.checkEntrypoint(kind: "exec", fileURL: script))
        XCTAssertNoThrow(try PackageGates.checkEntrypoint(kind: "jxa", fileURL: script))
    }

    func testReservedAndInvalidIds() {
        XCTAssertThrowsError(try PackageGates.validateAddonId(".staging"))
        XCTAssertThrowsError(try PackageGates.validateAddonId(".foo"))
        XCTAssertThrowsError(try PackageGates.validateAddonId("Foo"))
        XCTAssertNoThrow(try PackageGates.validateAddonId("clip-tools"))
        XCTAssertNoThrow(try PackageGates.validateAddonId("jugnu.clip-tools"))
        XCTAssertNoThrow(try PackageGates.validateNamespacedAddonId("jugnu.clip-tools"))
        XCTAssertThrowsError(try PackageGates.validateNamespacedAddonId("clip-tools"))
    }
}
