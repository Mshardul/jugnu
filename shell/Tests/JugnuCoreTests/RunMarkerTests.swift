@testable import JugnuCore
import XCTest

final class RunMarkerTests: XCTestCase {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func test_roundTrip_encodesClassKeyAsClass() throws {
        let marker = RunMarker(
            origin: "a:b:c",
            lifecycleClass: "job",
            shellPID: 42,
            shellStartTS: 1234.5,
            spawnedAt: 9999.0
        )
        let data = try JSONEncoder().encode(marker)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"class\":\"job\""))
        let decoded = try JSONDecoder().decode(RunMarker.self, from: data)
        XCTAssertEqual(decoded, marker)
    }

    func test_writeThenEnumerate_returnsMarker() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let marker = RunMarker(origin: "x:y:z", lifecycleClass: "oneshot", shellPID: 1, shellStartTS: 2, spawnedAt: 3)
        try RunMarker.write(marker, pid: 777, to: dir)
        let found = RunMarker.enumerate(in: dir)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.pid, 777)
        XCTAssertEqual(found.first?.marker, marker)
    }

    func test_enumerate_missingDir_returnsEmpty() {
        XCTAssertTrue(RunMarker.enumerate(in: tempDir()).isEmpty)
    }

    func test_enumerate_toleratesGarbageAndUnreadable() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not json".write(to: dir.appendingPathComponent("123.json"), atomically: true, encoding: .utf8)
        try "junk".write(to: dir.appendingPathComponent("notapid.json"), atomically: true, encoding: .utf8)
        try "x".write(to: dir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        let found = RunMarker.enumerate(in: dir)
        XCTAssertEqual(found.map(\.pid), [123])
        XCTAssertNil(found.first?.marker)
    }

    func test_delete_removesMarker() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let marker = RunMarker(origin: "a", lifecycleClass: "oneshot", shellPID: 0, shellStartTS: 0, spawnedAt: 0)
        try RunMarker.write(marker, pid: 5, to: dir)
        RunMarker.delete(pid: 5, in: dir)
        XCTAssertTrue(RunMarker.enumerate(in: dir).isEmpty)
    }
}
