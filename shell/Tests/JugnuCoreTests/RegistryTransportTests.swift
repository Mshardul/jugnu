@testable import JugnuCore
import XCTest

final class RegistryTransportTests: XCTestCase {
    func testAllowsOnlyHTTPSAndFile() throws {
        XCTAssertTrue(try RegistryTransport
            .isAllowed(XCTUnwrap(URL(string: "https://raw.githubusercontent.com/x/addons.json"))))
        XCTAssertTrue(RegistryTransport.isAllowed(URL(fileURLWithPath: "/tmp/addons.json")))
        XCTAssertFalse(try RegistryTransport.isAllowed(XCTUnwrap(URL(string: "http://example.com/addons.json"))))
        XCTAssertFalse(try RegistryTransport.isAllowed(XCTUnwrap(URL(string: "ftp://example.com/addons.json"))))
    }

    func testHTTPRegistryIsRejectedBeforeAnyRequest() async throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/addons.json"))
        do {
            _ = try await RegistryClient().fetch(from: url)
            XCTFail("expected insecureURL")
        } catch {
            XCTAssertEqual(error as? RegistryClientError, .insecureURL)
        }
    }

    func testOversizedLocalRegistryIsRejected() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(repeating: 0x20, count: RegistryTransport.maxBytes + 1).write(to: file)
        do {
            _ = try await RegistryClient().fetch(from: file)
            XCTFail("expected tooLarge")
        } catch {
            XCTAssertEqual(error as? RegistryClientError, .tooLarge)
        }
    }
}
