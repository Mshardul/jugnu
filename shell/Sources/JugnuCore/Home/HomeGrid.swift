import CoreGraphics
import Foundation

public struct HomeGridTokens: Equatable, Sendable {
    public var frameSafeMargin: CGFloat
    public var unitMinWidth: CGFloat
    public var unitRowHeight: CGFloat
    public var gap: CGFloat
    public var maxColumns: Int

    public init(
        frameSafeMargin: CGFloat,
        unitMinWidth: CGFloat,
        unitRowHeight: CGFloat,
        gap: CGFloat,
        maxColumns: Int
    ) {
        self.frameSafeMargin = frameSafeMargin
        self.unitMinWidth = unitMinWidth
        self.unitRowHeight = unitRowHeight
        self.gap = gap
        self.maxColumns = maxColumns
    }

    public static let reference = HomeGridTokens(
        frameSafeMargin: 32,
        unitMinWidth: 160,
        unitRowHeight: 96,
        gap: 12,
        maxColumns: 12
    )
}

public struct WidgetSpanLimits: Equatable, Sendable {
    public var minColumns: Int
    public var maxColumns: Int
    public var minRows: Int
    public var maxRows: Int

    public init(minColumns: Int, maxColumns: Int, minRows: Int, maxRows: Int) {
        self.minColumns = minColumns
        self.maxColumns = maxColumns
        self.minRows = minRows
        self.maxRows = maxRows
    }
}

public struct HomeSpan: Equatable, Sendable {
    public var id: String
    public var columnSpan: Int
    public var rowSpan: Int

    public init(id: String, columnSpan: Int, rowSpan: Int) {
        self.id = id
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
    }
}

public struct HomePlacement: Equatable, Sendable {
    public var id: String
    public var column: Int
    public var row: Int
    public var columnSpan: Int
    public var rowSpan: Int

    public init(id: String, column: Int, row: Int, columnSpan: Int, rowSpan: Int) {
        self.id = id
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
    }

    public func contains(column: Int, row: Int) -> Bool {
        column >= self.column
            && column < self.column + columnSpan
            && row >= self.row
            && row < self.row + rowSpan
    }
}

public func appShellFrame(
    in visible: CGRect,
    margin: CGFloat = HomeGridTokens.reference.frameSafeMargin
) -> CGRect {
    guard visible.width > margin * 2, visible.height > margin * 2 else { return visible }
    return CGRect(
        x: visible.minX + margin,
        y: visible.minY + margin,
        width: visible.width - margin * 2,
        height: visible.height - margin * 2
    )
}

public func homeColumnCount(
    contentWidth: CGFloat,
    tokens: HomeGridTokens = .reference
) -> Int {
    let divisor = tokens.unitMinWidth + tokens.gap
    guard divisor > 0 else { return 1 }
    let raw = Int(floor((contentWidth + tokens.gap) / divisor))
    return min(tokens.maxColumns, max(1, raw))
}

public func effectiveRowHeight(
    _ preferred: CGFloat,
    tokens: HomeGridTokens = .reference
) -> CGFloat {
    max(preferred, tokens.unitRowHeight)
}

public func resolvedColumnSpan(
    preferred: ExactRational,
    columnCount: Int,
    limits: WidgetSpanLimits
) -> Int {
    let columns = max(1, columnCount)
    if columns < limits.minColumns {
        return columns
    }
    let raw = roundHalfUp(preferred, times: columns)
    let limited = min(max(raw, limits.minColumns), limits.maxColumns)
    return min(max(1, limited), columns)
}

public func resolvedRowSpan(preferredRows: Int, limits: WidgetSpanLimits) -> Int {
    min(max(preferredRows, limits.minRows), limits.maxRows)
}

public func preferredWidth(finalSpan: Int, columnCount: Int) -> ExactRational {
    ExactRational(max(0, finalSpan), max(1, columnCount))
}

public func packHome(spans: [HomeSpan], columnCount: Int) -> [HomePlacement] {
    let columns = max(1, columnCount)
    var occupied = Set<GridCell>()
    var placements: [HomePlacement] = []
    for span in spans {
        let columnSpan = min(columns, max(1, span.columnSpan))
        let rowSpan = max(1, span.rowSpan)
        let origin = firstOpenOrigin(
            columnSpan: columnSpan,
            rowSpan: rowSpan,
            columns: columns,
            occupied: occupied
        )
        for row in origin.row ..< (origin.row + rowSpan) {
            for column in origin.column ..< (origin.column + columnSpan) {
                occupied.insert(GridCell(column: column, row: row))
            }
        }
        placements.append(
            HomePlacement(
                id: span.id,
                column: origin.column,
                row: origin.row,
                columnSpan: columnSpan,
                rowSpan: rowSpan
            )
        )
    }
    return placements
}

public func visualWidgetOrder(_ placed: [HomePlacement]) -> [String] {
    placed.sorted { lhs, rhs in
        if lhs.row != rhs.row {
            return lhs.row < rhs.row
        }
        return lhs.column < rhs.column
    }.map(\.id)
}

public func homeOrderAfterDrop(
    order: [String],
    moving id: String,
    placed: [HomePlacement],
    column: Int,
    row: Int
) -> [String] {
    var reduced = order
    reduced.removeAll { $0 == id }
    let others = placed.filter { $0.id != id }
    if let occupant = others.first(where: { $0.contains(column: column, row: row) }),
       let index = reduced.firstIndex(of: occupant.id)
    {
        reduced.insert(id, at: index)
        return reduced
    }
    let preceding = others.filter { placement in
        placement.row < row || (placement.row == row && placement.column < column)
    }
    if let last = preceding.max(by: { lhs, rhs in
        if lhs.row != rhs.row {
            return lhs.row < rhs.row
        }
        return lhs.column < rhs.column
    }), let index = reduced.firstIndex(of: last.id) {
        reduced.insert(id, at: index + 1)
        return reduced
    }
    reduced.insert(id, at: 0)
    return reduced
}

private struct GridCell: Hashable {
    var column: Int
    var row: Int
}

private func firstOpenOrigin(
    columnSpan: Int,
    rowSpan: Int,
    columns: Int,
    occupied: Set<GridCell>
) -> (column: Int, row: Int) {
    let highest = occupied.map(\.row).max() ?? -1
    let lastColumn = columns - columnSpan
    for row in 0 ... (highest + 1) {
        guard lastColumn >= 0 else { continue }
        for column in 0 ... lastColumn where regionIsOpen(
            column: column,
            row: row,
            columnSpan: columnSpan,
            rowSpan: rowSpan,
            occupied: occupied
        ) {
            return (column, row)
        }
    }
    return (0, highest + 2)
}

private func regionIsOpen(
    column: Int,
    row: Int,
    columnSpan: Int,
    rowSpan: Int,
    occupied: Set<GridCell>
) -> Bool {
    for occupiedRow in row ..< (row + rowSpan) {
        for occupiedColumn in column ..< (column + columnSpan) where contains(
            occupied,
            column: occupiedColumn,
            row: occupiedRow
        ) {
            return false
        }
    }
    return true
}

private func contains(_ occupied: Set<GridCell>, column: Int, row: Int) -> Bool {
    occupied.contains(GridCell(column: column, row: row))
}
