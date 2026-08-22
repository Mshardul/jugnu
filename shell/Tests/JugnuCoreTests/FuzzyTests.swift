import XCTest
@testable import JugnuCore

final class FuzzyTests: XCTestCase {
    func testMcmtMatchesMicMuteTitle() {
        XCTAssertGreaterThan(Fuzzy.score(query: "mcmt", in: "Mic Mute"), 0)
        XCTAssertEqual(Fuzzy.score(query: "zzzz", in: "Mic Mute"), 0)
    }

    func testEditDistanceZeroForSameFoldedText() {
        XCTAssertEqual(Fuzzy.editDistance("mic", "mic"), 0)
        XCTAssertGreaterThan(Fuzzy.editDistance("nope", "micmute"), 0)
    }
}
