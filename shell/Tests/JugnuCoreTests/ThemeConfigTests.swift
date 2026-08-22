import XCTest
import Yams
@testable import JugnuCore

final class ThemeConfigTests: XCTestCase {
    func testDefaultThemeIsFireflyDarkAccent() {
        XCTAssertEqual(ThemeConfig.firefly.dark.accent, "#F5A623")
        XCTAssertEqual(ThemeConfig.firefly.light.background, "#F7F3EA")
        XCTAssertEqual(ThemeConfig.firefly.dark.error, "#E5484D")
    }

    func testSanitizeInvalidHexUsesDefaultForThatFieldOnly() {
        var dirty = ThemeConfig.firefly.dark
        dirty.accent = "not-a-color"
        dirty.background = "#16130E"
        let clean = dirty.sanitized(against: ThemeConfig.firefly.dark)
        XCTAssertEqual(clean.accent, "#F5A623")
        XCTAssertEqual(clean.background, "#16130E")
    }

    func testPhosphorAndRoseQuartzAccents() {
        XCTAssertEqual(ThemeConfig.terminalPhosphor.dark.accent, "#39FF6A")
        XCTAssertEqual(ThemeConfig.roseQuartz.dark.accent, "#F0559B")
        XCTAssertEqual(ThemeConfig.terminalPhosphor.dark.error, "#E5484D")
        XCTAssertEqual(ThemeConfig.roseQuartz.light.error, "#E5484D")
    }

    func testJugnuConfigDecodesMissingThemeAsFirefly() throws {
        let yaml = "version: 1\nshell:\n  hotkey: option+space\naddons: {}\n"
        let config = try YAMLDecoder().decode(JugnuConfig.self, from: yaml)
        XCTAssertEqual(config.theme, .firefly)
        XCTAssertEqual(config.sound, true)
        XCTAssertEqual(config.palette.firstView, .blank)
        XCTAssertEqual(config.ui, [:])
    }
}
