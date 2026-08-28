@testable import JugnuCore
@testable import JugnuUI
import SwiftUI
import XCTest

final class JugnuThemeColorsTests: XCTestCase {
    func test_subText_resolvesFromTheme() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertEqual(colors.subText, Color(jugnuHex: "#B8AF9E", fallback: .gray))
    }

    func test_border_isDerived_notEqualToSurface() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertNotEqual(colors.border, colors.surface, "border must be a distinct derived value, not aliased to surface")
    }

    func test_surface2_isDerived_notEqualToSurface() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertNotEqual(colors.surface2, colors.surface)
    }

    func test_accentDeep_isDerived_notEqualToAccent() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertNotEqual(colors.accentDeep, colors.accent)
    }
}
