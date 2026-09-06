@testable import JugnuCore
import XCTest

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
            UserFacingError.message(for: AddonRunnerError.jobHandshakeTimeout),
            "The addon didn't start in time."
        )
        XCTAssertEqual(
            UserFacingError.message(for: AddonRunnerError.jobUnresponsive),
            "The addon stopped responding."
        )
        XCTAssertEqual(
            UserFacingError.message(for: JobInvokeError.stillStopping),
            JobProgressCopy.stillStopping
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
        XCTAssertEqual(message, UserFacingError.catalogUnreachable)
    }

    func testRegistryInvalidCatalogDoesNotLookLikeNetworkFailure() {
        XCTAssertEqual(
            UserFacingError.message(for: RegistryClientError.invalidCatalog),
            UserFacingError.catalogInvalid
        )
        XCTAssertEqual(
            UserFacingError.message(for: RegistryFetchFailure.invalid),
            UserFacingError.catalogInvalid
        )
        XCTAssertEqual(
            UserFacingError.message(for: RegistryFetchFailure.unreachable),
            UserFacingError.catalogUnreachable
        )
        XCTAssertNotEqual(UserFacingError.catalogInvalid, UserFacingError.catalogUnreachable)
    }

    func testAppUpdateErrorsArePlainLanguage() {
        XCTAssertEqual(
            UserFacingError.message(for: AppUpdateError.sha256Required),
            "This package is missing a checksum. Nothing was installed."
        )
        XCTAssertEqual(
            UserFacingError.message(for: AppUpdateError.invalidRegistryURL),
            "The catalog URL isn't valid."
        )
        XCTAssertFalse(UserFacingError.message(for: AppUpdateError.invalidId("x")).contains("invalidId"))
        XCTAssertEqual(
            UserFacingError.message(for: AppUpdateError.versionMismatch(expected: "0.2.0", actual: "0.1.0")),
            "The downloaded app didn’t match the catalog. Nothing was installed."
        )
        XCTAssertEqual(
            UserFacingError.message(for: AppUpdateError.bundleIdentity),
            "The downloaded app isn’t a Jugnu app. Nothing was installed."
        )
        XCTAssertEqual(
            UserFacingError.message(for: AppUpdateError.destNotWritable),
            "Jugnu can’t replace itself here. Move it to Applications and try again."
        )
        XCTAssertEqual(
            UserFacingError.message(for: AppUpdateError.helperSpawnFailed),
            "Couldn’t start the updater. Try again."
        )
    }
}
