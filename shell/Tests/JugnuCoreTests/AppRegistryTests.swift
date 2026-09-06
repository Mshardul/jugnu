@testable import JugnuCore
import XCTest

final class AppRegistryTests: XCTestCase {
    private let validJSON = """
    {
      "id": "jugnu.shell",
      "name": "Jugnu",
      "version": "0.2.0",
      "minMacOS": "14.0",
      "url": "https://github.com/Mshardul/jugnu/releases/download/shell-v0.2.0/Jugnu-0.2.0.zip",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
    """

    func testDecodesRequiredFields() throws {
        let entry = try JSONDecoder().decode(AppRegistryEntry.self, from: Data(validJSON.utf8))
        XCTAssertEqual(entry.id, "jugnu.shell")
        XCTAssertEqual(entry.version, "0.2.0")
        XCTAssertEqual(entry.minMacOS, "14.0")
        XCTAssertNil(entry.notes)
    }

    func testEmptySha256Throws() {
        let json = validJSON.replacingOccurrences(
            of: "\"sha256\": \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"",
            with: "\"sha256\": \"\""
        )
        XCTAssertThrowsError(try JSONDecoder().decode(AppRegistryEntry.self, from: Data(json.utf8))) {
            XCTAssertEqual($0 as? AppUpdateError, .sha256Required)
        }
    }

    func testMissingSha256Throws() {
        let json = """
        {
          "id": "jugnu.shell",
          "name": "Jugnu",
          "version": "0.2.0",
          "minMacOS": "14.0",
          "url": "https://github.com/Mshardul/jugnu/releases/download/shell-v0.2.0/Jugnu-0.2.0.zip"
        }
        """
        XCTAssertThrowsError(try JSONDecoder().decode(AppRegistryEntry.self, from: Data(json.utf8))) {
            XCTAssertEqual($0 as? AppUpdateError, .sha256Required)
        }
    }

    func testWrongIdThrows() {
        let json = validJSON.replacingOccurrences(of: "jugnu.shell", with: "other.app")
        XCTAssertThrowsError(try JSONDecoder().decode(AppRegistryEntry.self, from: Data(json.utf8))) {
            XCTAssertEqual($0 as? AppUpdateError, .invalidId("other.app"))
        }
    }

    func testFetchAppRegistryFromFile() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("jugnu-app.json")
        try Data(validJSON.utf8).write(to: file)
        let entry = try await RegistryClient().fetchAppRegistry(from: file)
        XCTAssertEqual(entry.version, "0.2.0")
    }

    func testFetchAppRegistryInvalidJSON() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("bad.json")
        try Data("[]".utf8).write(to: file)
        do {
            _ = try await RegistryClient().fetchAppRegistry(from: file)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? RegistryClientError, .invalidCatalog)
        }
    }

    func testAppRegistryURLDerivation() {
        XCTAssertEqual(
            ShellConfig.appRegistryURL(from: ShellConfig.defaultRegistryURL),
            "https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/jugnu-app.json"
        )
        XCTAssertNil(ShellConfig.appRegistryURL(from: "https://example.com/catalog"))
    }
}
