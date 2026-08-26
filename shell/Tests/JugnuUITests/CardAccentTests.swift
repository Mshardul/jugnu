@testable import JugnuUI
import XCTest

final class CardAccentTests: XCTestCase {
    func test_init_sixDigitHex_parsesOpaqueColor() throws {
        let accent = try XCTUnwrap(CardAccent(hex: "#4A90D9"))

        XCTAssertEqual(accent.red, 74.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(accent.green, 144.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(accent.blue, 217.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(accent.alpha, 1)
    }

    func test_init_eightDigitHex_parsesAlpha() throws {
        let accent = try XCTUnwrap(CardAccent(hex: "#4A90D980"))

        XCTAssertEqual(accent.alpha, 128.0 / 255.0, accuracy: 0.001)
    }

    func test_init_invalidHex_returnsNil() {
        XCTAssertNil(CardAccent(hex: "4A90D9"))
        XCTAssertNil(CardAccent(hex: "#nothex"))
    }
}
