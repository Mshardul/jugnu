import XCTest
@testable import JugnuCore

final class ViewTypeTests: XCTestCase {
    private let laptop = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let portrait = CGRect(x: 0, y: 0, width: 1080, height: 1920)
    private let ultrawide = CGRect(x: 0, y: 0, width: 5120, height: 1440)
    private let tiny = CGRect(x: 100, y: 80, width: 800, height: 500)

    func testLaptopSeekAndPaletteMatchCompactAndFullLauncher() {
        let seek = ViewType.seek.size(in: laptop)
        XCTAssertEqual(seek.width, 560, accuracy: 0.5)
        XCTAssertEqual(seek.height, 120, accuracy: 0.5)

        let palette = ViewType.palette.size(in: laptop)
        XCTAssertEqual(palette.width, 560, accuracy: 0.5)
        XCTAssertEqual(palette.height, 360, accuracy: 0.5)
    }

    func testCanvasClampsToMaxAndMin() {
        let huge = ViewType.canvas.size(in: ultrawide)
        XCTAssertLessThanOrEqual(huge.width, 1400)
        XCTAssertLessThanOrEqual(huge.height, 900)

        let small = ViewType.canvas.size(in: tiny)
        XCTAssertGreaterThanOrEqual(small.width, min(800, tiny.width))
        XCTAssertGreaterThanOrEqual(small.height, min(500, tiny.height))
        XCTAssertLessThanOrEqual(small.width, tiny.width)
        XCTAssertLessThanOrEqual(small.height, tiny.height)
    }

    func testBoardOnPortraitMonitorStaysLandscapePanel() {
        let size = ViewType.board.size(in: portrait)
        XCTAssertGreaterThan(size.width, size.height)
        XCTAssertLessThanOrEqual(size.width, portrait.width)
        XCTAssertLessThanOrEqual(size.height, portrait.height)
    }

    func testRailOnUltrawideStaysNarrow() {
        let size = ViewType.rail.size(in: ultrawide)
        XCTAssertLessThanOrEqual(size.width, 560)
        XCTAssertGreaterThan(size.height, size.width)
    }

    func testSizeUsesTheRectPassedInNotAGlobalScreen() {
        let a = ViewType.grid.size(in: laptop)
        let b = ViewType.grid.size(in: portrait)
        XCTAssertNotEqual(a, b)
    }

    func testClickOutsideIgnoredOnlyForBoardSpreadCanvas() {
        for type in ViewType.allCases {
            let ignores = type == .board || type == .spread || type == .canvas
            XCTAssertEqual(type.dismissesOnOutsideClick, !ignores, type.rawValue)
        }
    }

    func testShellDefaultsAreRowsFieldsAsk() {
        XCTAssertEqual(ViewType.shellDefaults, [.rows, .fields, .ask])
    }

    func testResolveUsesPatternDefaultWhenRequestOmitted() throws {
        XCTAssertEqual(
            try ViewType.resolve(pattern: .list, requested: nil, allowed: ViewType.shellDefaults),
            .rows
        )
        XCTAssertEqual(
            try ViewType.resolve(pattern: .form, requested: nil, allowed: ViewType.shellDefaults),
            .fields
        )
        XCTAssertEqual(
            try ViewType.resolve(pattern: .confirm, requested: nil, allowed: ViewType.shellDefaults),
            .ask
        )
        XCTAssertNil(try ViewType.resolve(pattern: .note, requested: nil, allowed: ViewType.shellDefaults))
    }

    func testResolveAcceptsOverrideWhenAllowed() throws {
        XCTAssertEqual(
            try ViewType.resolve(pattern: .list, requested: .board, allowed: [.board, .rows]),
            .board
        )
    }

    func testResolveRejectsOverrideOutsideAllowList() {
        XCTAssertThrowsError(
            try ViewType.resolve(pattern: .list, requested: .board, allowed: ViewType.shellDefaults)
        ) { error in
            XCTAssertEqual(error as? ViewTypeError, .notAllowed("board"))
        }
    }

    func testCatalogHasTenIds() {
        XCTAssertEqual(ViewType.allCases.map(\.rawValue).sorted(), [
            "ask", "board", "canvas", "fields", "grid", "palette", "rail", "rows", "seek", "spread",
        ])
    }
}
