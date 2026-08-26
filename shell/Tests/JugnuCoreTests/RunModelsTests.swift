@testable import JugnuCore
import XCTest

final class RunModelsTests: XCTestCase {
    func testToastResponseRoundTrip() throws {
        let json = Data(#"{"ok":true,"message":"Microphone muted"}"#.utf8)
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.message, "Microphone muted")
        XCTAssertNil(decoded.ui)
    }

    func testListResponseRoundTrip() throws {
        let json = Data("""
        {"ok":true,"ui":{"pattern":"list","title":"Processes","placeholder":"Filter",
         "items":[{"id":"1","title":"node","subtitle":"PID 1","actions":["quit"]}]}}
        """.utf8)
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertEqual(decoded.ui?.pattern, .list)
        XCTAssertEqual(decoded.ui?.items?.first?.id, "1")
    }

    func testNoteResponseRoundTrip() throws {
        let json = Data("""
        {"ok":true,"ui":{"pattern":"note","title":"Scratch","content":"hello world"}}
        """.utf8)
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertEqual(decoded.ui?.pattern, .note)
        XCTAssertEqual(decoded.ui?.content, "hello world")
    }

    func testUIViewTypeRoundTrip() throws {
        let json = Data(#"{"ok":true,"ui":{"pattern":"list","title":"Zones","view":"board","items":[]}}"#.utf8)
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertEqual(decoded.ui?.view, .board)
    }

    func testDecodesCardUI() throws {
        let json = Data("""
        {"ok":true,"ui":{"pattern":"card","emoji":"👀","message":"Glow farther.","accent":"#4A90D9","title":"Eyes"}}
        """.utf8)
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertEqual(decoded.ui?.pattern, .card)
        XCTAssertEqual(decoded.ui?.emoji, "👀")
        XCTAssertEqual(decoded.ui?.accent, "#4A90D9")
    }

    func testRequestEncodesEmptyContext() throws {
        let req = RunRequest(api: 1, op: "run", command: "toggle", args: [:], context: [:])
        let data = try JSONEncoder().encode(req)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["api"] as? Int, 1)
        XCTAssertEqual(obj["command"] as? String, "toggle")
        XCTAssertNotNil(obj["context"])
    }
}
