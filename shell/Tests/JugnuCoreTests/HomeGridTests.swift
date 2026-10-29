import CoreGraphics
@testable import JugnuCore
import XCTest

final class HomeGridTests: XCTestCase {
    func test_columnCount_usesReferenceTokens() {
        XCTAssertEqual(homeColumnCount(contentWidth: 1376), 8)
        XCTAssertEqual(homeColumnCount(contentWidth: 100), 1)
        XCTAssertEqual(homeColumnCount(contentWidth: 3000), 12)
        XCTAssertEqual(homeColumnCount(contentWidth: 159), 1)
    }

    func test_appShellFrame_insetsTheVisibleFrameByTheSafeMargin() {
        let visible = CGRect(x: 100, y: 80, width: 1440, height: 900)
        let frame = appShellFrame(in: visible)
        XCTAssertEqual(frame, CGRect(x: 132, y: 112, width: 1376, height: 836))
    }

    func test_appShellFrame_usesTheVisibleFrameWhenTheMarginDoesNotFit() {
        let visible = CGRect(x: 0, y: 0, width: 40, height: 40)
        XCTAssertEqual(appShellFrame(in: visible), visible)
    }

    func test_exactRational_reducesToLowestTerms() {
        XCTAssertEqual(ExactRational(2, 4), ExactRational(1, 2))
        XCTAssertEqual(ExactRational(3, 12), ExactRational(1, 4))
    }

    func test_roundHalfUp_mapsPreferredWidthOntoColumns() {
        XCTAssertEqual(roundHalfUp(ExactRational(1, 2), times: 5), 3)
        XCTAssertEqual(roundHalfUp(ExactRational(1, 2), times: 4), 2)
        XCTAssertEqual(roundHalfUp(ExactRational(1, 3), times: 2), 1)
    }

    func test_resolvedSpan_clampsToLimitsThenAvailableColumns() {
        let limits = WidgetSpanLimits(minColumns: 2, maxColumns: 6, minRows: 1, maxRows: 4)
        XCTAssertEqual(
            resolvedColumnSpan(preferred: ExactRational(1, 2), columnCount: 12, limits: limits),
            6
        )
        XCTAssertEqual(
            resolvedColumnSpan(preferred: ExactRational(1, 10), columnCount: 8, limits: limits),
            2
        )
    }

    func test_narrowScreen_spansEveryColumnWithoutChangingTheStoredWidth() {
        let limits = WidgetSpanLimits(minColumns: 3, maxColumns: 8, minRows: 1, maxRows: 4)
        let preferred = ExactRational(1, 2)
        XCTAssertEqual(resolvedColumnSpan(preferred: preferred, columnCount: 1, limits: limits), 1)
        XCTAssertEqual(preferred, ExactRational(1, 2))
        XCTAssertEqual(resolvedColumnSpan(preferred: preferred, columnCount: 8, limits: limits), 4)
    }

    func test_resolvedRowSpan_clampsToTheDefinition() {
        let limits = WidgetSpanLimits(minColumns: 1, maxColumns: 4, minRows: 2, maxRows: 3)
        XCTAssertEqual(resolvedRowSpan(preferredRows: 1, limits: limits), 2)
        XCTAssertEqual(resolvedRowSpan(preferredRows: 9, limits: limits), 3)
    }

    func test_effectiveRowHeight_neverDropsBelowTheMinimum() {
        XCTAssertEqual(effectiveRowHeight(96), 96)
        XCTAssertEqual(effectiveRowHeight(128), 128)
        XCTAssertEqual(effectiveRowHeight(40), 96)
    }

    func test_pack_fillsAnEarlierHoleWithoutShrinkingALaterSpan() {
        let placed = packHome(
            spans: [
                HomeSpan(id: "A", columnSpan: 3, rowSpan: 1),
                HomeSpan(id: "B", columnSpan: 2, rowSpan: 1),
                HomeSpan(id: "C", columnSpan: 1, rowSpan: 1)
            ],
            columnCount: 4
        )
        XCTAssertEqual(placed, [
            HomePlacement(id: "A", column: 0, row: 0, columnSpan: 3, rowSpan: 1),
            HomePlacement(id: "B", column: 0, row: 1, columnSpan: 2, rowSpan: 1),
            HomePlacement(id: "C", column: 3, row: 0, columnSpan: 1, rowSpan: 1)
        ])
    }

    func test_visualOrder_followsPackedRowMajorNotStableOrder() {
        let placed = packHome(
            spans: [
                HomeSpan(id: "A", columnSpan: 3, rowSpan: 1),
                HomeSpan(id: "B", columnSpan: 2, rowSpan: 1),
                HomeSpan(id: "C", columnSpan: 1, rowSpan: 1)
            ],
            columnCount: 4
        )
        XCTAssertEqual(visualWidgetOrder(placed), ["A", "C", "B"])
    }

    func test_dropOverAnOccupiedCell_insertsBeforeThatInstance() {
        let placed = sampleRow()
        let order = homeOrderAfterDrop(order: ["A", "B", "C"], moving: "D", placed: placed, column: 2, row: 0)
        XCTAssertEqual(order, ["A", "D", "B", "C"])
    }

    func test_dropInEmptySpaceAfterC_appends() {
        let placed = sampleRow()
        let order = homeOrderAfterDrop(order: ["A", "B", "C"], moving: "D", placed: placed, column: 2, row: 1)
        XCTAssertEqual(order, ["A", "B", "C", "D"])
    }

    func test_dropPreview_repacksTheInsertedOrder() {
        var spans = [
            HomeSpan(id: "A", columnSpan: 2, rowSpan: 1),
            HomeSpan(id: "B", columnSpan: 2, rowSpan: 1),
            HomeSpan(id: "C", columnSpan: 2, rowSpan: 1)
        ]
        let placed = packHome(spans: spans, columnCount: 4)
        let order = homeOrderAfterDrop(order: ["A", "B", "C"], moving: "D", placed: placed, column: 2, row: 0)
        spans.insert(HomeSpan(id: "D", columnSpan: 2, rowSpan: 1), at: 1)
        XCTAssertEqual(order, spans.map(\.id))
        let preview = packHome(spans: spans, columnCount: 4)
        XCTAssertEqual(preview.first { $0.id == "D" }?.column, 2)
        XCTAssertEqual(preview.first { $0.id == "D" }?.row, 0)
    }

    func test_resize_storesTheFinalSpanAsAReducedFraction() {
        XCTAssertEqual(preferredWidth(finalSpan: 3, columnCount: 12), ExactRational(1, 4))
        XCTAssertEqual(preferredWidth(finalSpan: 2, columnCount: 4), ExactRational(1, 2))
    }

    private func sampleRow() -> [HomePlacement] {
        packHome(
            spans: [
                HomeSpan(id: "A", columnSpan: 2, rowSpan: 1),
                HomeSpan(id: "B", columnSpan: 2, rowSpan: 1),
                HomeSpan(id: "C", columnSpan: 2, rowSpan: 1)
            ],
            columnCount: 4
        )
    }
}
