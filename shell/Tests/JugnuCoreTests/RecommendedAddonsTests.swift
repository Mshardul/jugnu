@testable import JugnuCore
import XCTest

final class RecommendedAddonsTests: XCTestCase {
    func testRecommendedSetIsTheCuratedFive() {
        XCTAssertEqual(
            ShellConfig.recommendedAddonIDs,
            ["jugnu.audio-toggles", "jugnu.focus-toggle", "jugnu.clip-tools", "jugnu.floating-note", "jugnu.ports"]
        )
    }
}
