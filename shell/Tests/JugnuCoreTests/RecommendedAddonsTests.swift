@testable import JugnuCore
import XCTest

final class RecommendedAddonsTests: XCTestCase {
    func testRecommendedSetIsTheCuratedFive() {
        XCTAssertEqual(
            ShellConfig.recommendedAddonIDs,
            ["mic-mute", "focus-toggle", "paste-plain", "floating-note", "ports"]
        )
    }
}
