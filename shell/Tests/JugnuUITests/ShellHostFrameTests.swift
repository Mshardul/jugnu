import XCTest
import AppKit
@testable import JugnuUI

final class ShellHostFrameTests: XCTestCase {
    func test_clampedFrame_centersWithinScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 560)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(frame.midY, screen.midY, accuracy: 0.5)
    }

    func test_clampedFrame_shrinksWhenLargerThanScreen() {
        let screen = NSRect(x: 0, y: 0, width: 400, height: 300)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertLessThanOrEqual(frame.width, screen.width)
        XCTAssertLessThanOrEqual(frame.height, screen.height)
    }

    func test_clampedFrame_staysInsideScreenBounds() {
        let screen = NSRect(x: 100, y: 50, width: 1440, height: 900)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertTrue(screen.contains(CGPoint(x: frame.minX, y: frame.minY)))
        XCTAssertTrue(screen.contains(CGPoint(x: frame.maxX - 1, y: frame.maxY - 1)))
    }
}
