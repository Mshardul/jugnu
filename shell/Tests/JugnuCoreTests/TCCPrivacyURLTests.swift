@testable import JugnuCore
import XCTest

final class TCCPrivacyURLTests: XCTestCase {
    func testTCCIdsHavePrivacyURLs() {
        for permission in AddonPermission.allCases where permission.isTCC {
            XCTAssertNotNil(
                TCCPrivacyURL.systemSettingsURL(for: permission),
                "\(permission.rawValue) should have a Privacy pane URL"
            )
        }
    }

    func testNonTCCIdsHaveNoURL() {
        for permission in AddonPermission.allCases where !permission.isTCC {
            XCTAssertNil(TCCPrivacyURL.systemSettingsURL(for: permission))
        }
    }

    func testAccessibilityURL() {
        let url = TCCPrivacyURL.systemSettingsURL(for: .accessibility)
        XCTAssertEqual(
            url?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }
}
