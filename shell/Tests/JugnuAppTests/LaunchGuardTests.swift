@testable import Jugnu
import XCTest

final class LaunchGuardTests: XCTestCase {
    private func tempFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("launch-attempts")
    }

    func test_threeUnclearedAttempts_enterSafeMode() throws {
        let file = try tempFile()
        let lg = LaunchGuard(fileURL: file)
        XCTAssertFalse(lg.shouldEnterSafeMode)
        lg.recordAttempt()
        lg.recordAttempt()
        XCTAssertFalse(lg.shouldEnterSafeMode)
        lg.recordAttempt()
        XCTAssertTrue(lg.shouldEnterSafeMode)
        XCTAssertEqual(lg.count, 3)
    }

    func test_cleanLaunchResets() throws {
        let file = try tempFile()
        let lg = LaunchGuard(fileURL: file)
        lg.recordAttempt()
        lg.recordAttempt()
        lg.markCleanLaunch()
        lg.recordAttempt()
        XCTAssertFalse(lg.shouldEnterSafeMode)
        XCTAssertEqual(LaunchGuard(fileURL: file).count, 1)
    }

    func test_corruptCounter_isZero() throws {
        let file = try tempFile()
        try "not-a-number".write(to: file, atomically: true, encoding: .utf8)
        let lg = LaunchGuard(fileURL: file)
        XCTAssertFalse(lg.shouldEnterSafeMode)
        XCTAssertEqual(lg.count, 0)
    }

    func test_hangEqualsCrash_threeRecordAttempts() throws {
        let file = try tempFile()
        let a = LaunchGuard(fileURL: file)
        a.recordAttempt()
        let b = LaunchGuard(fileURL: file)
        b.recordAttempt()
        let c = LaunchGuard(fileURL: file)
        c.recordAttempt()
        XCTAssertTrue(c.shouldEnterSafeMode)
    }
}
