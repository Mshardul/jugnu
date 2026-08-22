import XCTest
@testable import JugnuCore

final class HotkeySpecTests: XCTestCase {
    func testOptionSpace() throws {
        let spec = try XCTUnwrap(HotkeySpec.parse("option+space"))
        XCTAssertEqual(spec.key, "space")
        XCTAssertEqual(spec.modifiers, ["option"])
    }

    func testCmdSpaceAliases() {
        XCTAssertEqual(HotkeySpec.parse("cmd+space"), HotkeySpec.parse("command+space"))
    }

    func testUnknownKeyIsNil() {
        XCTAssertNil(HotkeySpec.parse("option+f13x"))
    }
}
