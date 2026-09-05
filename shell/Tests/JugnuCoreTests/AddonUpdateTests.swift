import XCTest
@testable import JugnuCore

final class AddonUpdateTests: XCTestCase {
    func testBadgeWhenRegistryNewer() {
        XCTAssertTrue(AddonUpdate.isAvailable(installed: "1.0.0", registry: "1.0.1"))
        XCTAssertTrue(AddonUpdate.isAvailable(installed: "1.0.0", registry: "2.0.0"))
    }

    func testNoBadgeWhenSameOrOlder() {
        XCTAssertFalse(AddonUpdate.isAvailable(installed: "1.0.0", registry: "1.0.0"))
        XCTAssertFalse(AddonUpdate.isAvailable(installed: "2.0.0", registry: "1.9.9"))
        XCTAssertFalse(AddonUpdate.isAvailable(installed: nil, registry: "1.0.0"))
    }
}
