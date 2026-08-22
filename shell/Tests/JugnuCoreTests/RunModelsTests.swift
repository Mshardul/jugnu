import XCTest
@testable import JugnuCore

final class RunModelsTests: XCTestCase {
    func testToastResponseRoundTrip() throws {
        let json = #"{"ok":true,"message":"Microphone muted"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.message, "Microphone muted")
        XCTAssertNil(decoded.ui)
    }

    func testListResponseRoundTrip() throws {
        let json = """
        {"ok":true,"ui":{"pattern":"list","title":"Processes","placeholder":"Filter",
         "items":[{"id":"1","title":"node","subtitle":"PID 1","actions":["quit"]}]}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertEqual(decoded.ui?.pattern, .list)
        XCTAssertEqual(decoded.ui?.items?.first?.id, "1")
    }

    func testRequestEncodesEmptyContext() throws {
        let req = RunRequest(api: 1, op: "run", command: "toggle", args: [:], context: [:])
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["api"] as? Int, 1)
        XCTAssertEqual(obj["command"] as? String, "toggle")
        XCTAssertNotNil(obj["context"])
    }
}
