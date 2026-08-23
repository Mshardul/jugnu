import XCTest
@testable import JugnuCore

final class RegistryCacheTests: XCTestCase {
    private func makeHome() -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    func testFetchWithCacheWritesCacheOnSuccess() async throws {
        let home = makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)

        // Use a file:// URL so the test has no live network dependency.
        let sourceJSON = """
        [{"id":"a","name":"A","version":"1.0.0","api":1,"url":"https://x/a.zip","sha256":"x","summary":"s","category":"System"}]
        """
        let sourceFile = home.appendingPathComponent("source.json")
        try sourceJSON.write(to: sourceFile, atomically: true, encoding: .utf8)

        let result = await RegistryClient().fetchWithCache(from: sourceFile, cacheFile: paths.registryCacheFile)
        guard case .fresh(let entries) = result else { return XCTFail("expected .fresh, got \(result)") }
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.registryCacheFile.path))
    }

    func testFetchWithCacheFallsBackToCacheOnFailure() async throws {
        let home = makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        try FileManager.default.createDirectory(
            at: paths.registryCacheFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let cachedJSON = """
        [{"id":"b","name":"B","version":"1.0.0","api":1,"url":"https://x/b.zip","sha256":"x","summary":"s","category":"Focus"}]
        """
        try cachedJSON.write(to: paths.registryCacheFile, atomically: true, encoding: .utf8)

        let badURL = URL(fileURLWithPath: "/nonexistent/does-not-exist.json")
        let result = await RegistryClient().fetchWithCache(from: badURL, cacheFile: paths.registryCacheFile)
        guard case .cached(let entries, failure: .unreachable) = result else {
            return XCTFail("expected .cached(_, .unreachable), got \(result)")
        }
        XCTAssertEqual(entries.first?.id, "b")
    }

    func testFetchWithCacheUnavailableWhenNoCacheAndFetchFails() async throws {
        let home = makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        let badURL = URL(fileURLWithPath: "/nonexistent/does-not-exist.json")
        let result = await RegistryClient().fetchWithCache(from: badURL, cacheFile: paths.registryCacheFile)
        XCTAssertEqual(result, .unavailable(.unreachable))
    }

    func testFetchWithCacheInvalidJSONIsNotUnreachable() async throws {
        let home = makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        let sourceFile = home.appendingPathComponent("broken.json")
        try "not-json".write(to: sourceFile, atomically: true, encoding: .utf8)

        let result = await RegistryClient().fetchWithCache(from: sourceFile, cacheFile: paths.registryCacheFile)
        XCTAssertEqual(result, .unavailable(.invalid))
    }

    func testFetchWithCacheFallsBackToCacheOnInvalidJSON() async throws {
        let home = makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = JugnuPaths(home: home)
        try FileManager.default.createDirectory(
            at: paths.registryCacheFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let cachedJSON = """
        [{"id":"b","name":"B","version":"1.0.0","api":1,"url":"https://x/b.zip","sha256":"x","summary":"s","category":"Focus"}]
        """
        try cachedJSON.write(to: paths.registryCacheFile, atomically: true, encoding: .utf8)

        let sourceFile = home.appendingPathComponent("broken.json")
        try "not-json".write(to: sourceFile, atomically: true, encoding: .utf8)
        let result = await RegistryClient().fetchWithCache(from: sourceFile, cacheFile: paths.registryCacheFile)
        guard case .cached(let entries, failure: .invalid) = result else {
            return XCTFail("expected .cached(_, .invalid), got \(result)")
        }
        XCTAssertEqual(entries.first?.id, "b")
    }
}
