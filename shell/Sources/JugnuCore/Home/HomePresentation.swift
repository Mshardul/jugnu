import CoreGraphics
import Foundation

public struct PlacedHomeWidget: Equatable, Sendable {
    public var id: String
    public var definitionID: String
    public var name: String
    public var column: Int
    public var row: Int
    public var columnSpan: Int
    public var rowSpan: Int
    public var frame: CGRect

    public init(
        id: String,
        definitionID: String,
        name: String,
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        frame: CGRect
    ) {
        self.id = id
        self.definitionID = definitionID
        self.name = name
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
        self.frame = frame
    }
}

public func loadHomeLayout(from store: HomeLayoutStore) -> HomeLayoutSnapshot? {
    switch store.read() {
    case .missing:
        defaultHomeLayout()
    case let .ready(snapshot):
        snapshot
    case .newer, .unreadable:
        nil
    }
}

public func placedHomeWidgets(
    layout: HomeLayoutSnapshot,
    definitions: [WidgetDefinition],
    contentWidth: CGFloat,
    tokens: HomeGridTokens = .reference
) -> [PlacedHomeWidget] {
    let definitionsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    let columns = homeColumnCount(contentWidth: contentWidth, tokens: tokens)
    var spans: [HomeSpan] = []
    var names: [String: String] = [:]
    var definitionIDs: [String: String] = [:]
    for instance in layout.instances {
        guard let definition = definitionsByID[instance.definitionID] else { continue }
        spans.append(
            HomeSpan(
                id: instance.id,
                columnSpan: resolvedColumnSpan(
                    preferred: instance.preferredWidth,
                    columnCount: columns,
                    limits: definition.limits
                ),
                rowSpan: resolvedRowSpan(preferredRows: instance.preferredRows, limits: definition.limits)
            )
        )
        names[instance.id] = definition.name
        definitionIDs[instance.id] = definition.id
    }
    let placements = packHome(spans: spans, columnCount: columns)
    let byID = Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0) })
    let columnWidth = homeColumnWidth(contentWidth: contentWidth, columnCount: columns, gap: tokens.gap)
    return visualWidgetOrder(placements).compactMap { id in
        guard let placement = byID[id] else { return nil }
        return PlacedHomeWidget(
            id: placement.id,
            definitionID: definitionIDs[id] ?? "",
            name: names[id] ?? "",
            column: placement.column,
            row: placement.row,
            columnSpan: placement.columnSpan,
            rowSpan: placement.rowSpan,
            frame: homeWidgetFrame(
                placement: placement,
                columnWidth: columnWidth,
                rowHeight: tokens.unitRowHeight,
                gap: tokens.gap
            )
        )
    }
}

func homeColumnWidth(contentWidth: CGFloat, columnCount: Int, gap: CGFloat) -> CGFloat {
    guard columnCount > 0 else { return 0 }
    let gaps = gap * CGFloat(max(0, columnCount - 1))
    return max(0, (contentWidth - gaps) / CGFloat(columnCount))
}

func homeWidgetFrame(
    placement: HomePlacement,
    columnWidth: CGFloat,
    rowHeight: CGFloat,
    gap: CGFloat
) -> CGRect {
    let originX = CGFloat(placement.column) * (columnWidth + gap)
    let originY = CGFloat(placement.row) * (rowHeight + gap)
    let width = CGFloat(placement.columnSpan) * columnWidth
        + CGFloat(max(0, placement.columnSpan - 1)) * gap
    let height = CGFloat(placement.rowSpan) * rowHeight
        + CGFloat(max(0, placement.rowSpan - 1)) * gap
    return CGRect(x: originX, y: originY, width: width, height: height)
}
