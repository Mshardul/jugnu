@testable import JugnuCore
import XCTest

final class LifecycleLogTests: XCTestCase {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("lifecycle.log")
    }

    func test_record_appendsOneJSONLine() throws {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let log = LifecycleLog(fileURL: url, now: { Date(timeIntervalSince1970: 100) })
        log.recordNow(event: "reap", origin: "a:b:c", reason: "orphan")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)
        let event = try JSONDecoder().decode(LifecycleEvent.self, from: Data(lines[0].utf8))
        XCTAssertEqual(event.event, "reap")
        XCTAssertEqual(event.origin, "a:b:c")
    }

    func test_record_capsAtAround200Lines() throws {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let log = LifecycleLog(fileURL: url)
        for _ in 0 ..< 250 {
            log.recordNow(event: "reap")
        }
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        XCTAssertLessThanOrEqual(lines.count, 200)
        XCTAssertGreaterThan(lines.count, 150)
    }

    func test_record_corruptExistingFile_stillWrites() throws {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0x00, 0x01]).write(to: url)
        let log = LifecycleLog(fileURL: url)
        log.recordNow(event: "safe_mode", strikeCount: 3)
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.contains("safe_mode"))
    }
}
