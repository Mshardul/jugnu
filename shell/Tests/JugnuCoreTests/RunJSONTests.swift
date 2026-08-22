import XCTest
@testable import JugnuCore

final class RunJSONTests: XCTestCase {
    func testDecodeIgnoresTrailingWhitespace() throws {
        let data = "{\"ok\":true,\"message\":\"ok\"}\n".data(using: .utf8)!
        let r = try RunJSON.decodeResponse(stdout: data)
        XCTAssertEqual(r.message, "ok")
    }

    func testFollowUpIncludesItemId() throws {
        let req = RunJSON.followUpRequest(
            command: "list",
            args: ["itemId": .string("1234"), "action": .string("quit")]
        )
        XCTAssertEqual(req.op, "run")
        XCTAssertEqual(req.args["itemId"], .string("1234"))
    }
}
