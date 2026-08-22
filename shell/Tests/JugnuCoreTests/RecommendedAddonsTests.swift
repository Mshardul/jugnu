import XCTest
@testable import JugnuCore

final class RecommendedAddonsTests: XCTestCase {
    func testRecommendedSetIsTheCuratedFive() {
        XCTAssertEqual(
            ShellConfig.recommendedAddonIDs,
            ["mic-mute", "focus-toggle", "paste-plain", "floating-note", "ports"]
        )
    }
}
