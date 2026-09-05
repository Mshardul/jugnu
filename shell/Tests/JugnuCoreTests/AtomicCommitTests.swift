@testable import JugnuCore
import XCTest

final class AtomicCommitTests: XCTestCase {
    func testPromoteFreshAndReplace() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let liveParent = root.appendingPathComponent("addons")
        let stagingParent = liveParent.appendingPathComponent(".staging")
        let trashParent = liveParent.appendingPathComponent(".trash")
        let live = liveParent.appendingPathComponent("demo")
        let staging = stagingParent.appendingPathComponent("demo-1")

        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try "v1".write(to: staging.appendingPathComponent("marker"), atomically: true, encoding: .utf8)

        try AtomicCommit.promote(staging: staging, live: live, trashParent: trashParent)
        XCTAssertEqual(try String(contentsOf: live.appendingPathComponent("marker")), "v1")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))

        let staging2 = stagingParent.appendingPathComponent("demo-2")
        try FileManager.default.createDirectory(at: staging2, withIntermediateDirectories: true)
        try "v2".write(to: staging2.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
        try AtomicCommit.promote(staging: staging2, live: live, trashParent: trashParent)
        XCTAssertEqual(try String(contentsOf: live.appendingPathComponent("marker")), "v2")
        let trashChildren = try FileManager.default.contentsOfDirectory(at: trashParent, includingPropertiesForKeys: nil)
        XCTAssertTrue(trashChildren.isEmpty, "successful promote should remove trash entry")
    }

    func testRecoverOrphansClearsStagingAndTrash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent(".staging")
        let trash = root.appendingPathComponent(".trash")
        try FileManager.default.createDirectory(
            at: staging.appendingPathComponent("orphan"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: trash.appendingPathComponent("old"),
            withIntermediateDirectories: true
        )
        AtomicCommit.recoverOrphans(stagingParent: staging, trashParent: trash)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil).count,
            0
        )
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil).count,
            0
        )
    }
}
