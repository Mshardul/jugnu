import XCTest
@testable import JugnuCore

final class UserFacingErrorTests: XCTestCase {
    func testEmptyIdNeverLeaksEnumName() {
        let msg = UserFacingError.message(for: ManifestLoaderError.emptyId)
        XCTAssertEqual(msg, "This addon is missing its name. Try reinstalling it.")
        XCTAssertFalse(msg.contains("emptyId"))
        XCTAssertFalse(msg.contains("ManifestLoader"))
    }

    func testTimeoutAndUnknownFallbacks() {
        XCTAssertEqual(
            UserFacingError.message(for: AddonRunnerError.timeout),
            "That took too long. Try again."
        )
        XCTAssertEqual(
            UserFacingError.message(for: AddonInstallerError.missingURL),
            "No download location is listed for this addon."
        )
        struct Odd: Error {}
        XCTAssertEqual(UserFacingError.message(for: Odd()), "Something went wrong. Try again.")
        XCTAssertFalse(UserFacingError.message(for: Odd()).contains("Odd"))
    }

    func testRegistryClientHTTPStatusMapsToFriendlyMessage() {
        let message = UserFacingError.message(for: RegistryClientError.httpStatus(500))
        XCTAssertEqual(message, "Couldn’t reach the catalog. Check your connection and try again.")
    }
}
