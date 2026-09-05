@testable import JugnuCore
import XCTest

final class RecommendedAddonsTests: XCTestCase {
    func testRecommendedSetIsTheCuratedFive() {
        XCTAssertEqual(
            ShellConfig.recommendedAddonIDs,
            ["jugnu.mic-mute", "jugnu.focus-toggle", "jugnu.paste-plain", "jugnu.floating-note", "jugnu.ports"]
        )
    }
}
