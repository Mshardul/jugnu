import CoreGraphics
@testable import JugnuCore
import XCTest

final class HomePresentationTests: XCTestCase {
    func test_defaultHomeGrid_placesFavoritesRecentAndUpdatesAtHalfWidth() {
        let placed = placedHomeWidgets(
            layout: defaultHomeLayout(),
            definitions: builtInWidgetDefinitions(),
            contentWidth: 1376
        )

        XCTAssertEqual(placed.map(\.definitionID), [
            BuiltInWidget.favoriteAddons,
            BuiltInWidget.recentActivity,
            BuiltInWidget.updates
        ])
        XCTAssertEqual(placed.map(\.columnSpan), [4, 4, 4])
        XCTAssertEqual(placed.map(\.rowSpan), [3, 3, 2])
        XCTAssertEqual(placed.map(\.column), [0, 4, 0])
        XCTAssertEqual(placed.map(\.row), [0, 0, 3])
        XCTAssertFalse(placed.contains { $0.definitionID == BuiltInWidget.runningWork })
        XCTAssertEqual(placed[0].frame.width, 682, accuracy: 0.01)
        XCTAssertEqual(placed[0].frame.height, 312, accuracy: 0.01)
        XCTAssertEqual(
            placed.map(\.id),
            visualWidgetOrder(placed.map {
                HomePlacement(
                    id: $0.id,
                    column: $0.column,
                    row: $0.row,
                    columnSpan: $0.columnSpan,
                    rowSpan: $0.rowSpan
                )
            })
        )
    }

    func test_narrowHome_keepsTheDefaultWidgetsInOneColumn() {
        let placed = placedHomeWidgets(
            layout: defaultHomeLayout(),
            definitions: builtInWidgetDefinitions(),
            contentWidth: 100
        )
        XCTAssertEqual(placed.map(\.columnSpan), [1, 1, 1])
        XCTAssertEqual(placed.map(\.row), [0, 3, 6])
    }

    func test_unknownWidget_isLeftOutOfTheGrid() {
        let layout = HomeLayoutSnapshot(
            schemaVersion: HomeLayoutSchema.supported,
            instances: [
                HomeWidgetInstance(
                    id: "home.favorite-addons",
                    definitionID: BuiltInWidget.favoriteAddons,
                    preferredWidth: ExactRational(1, 2),
                    preferredRows: 3
                ),
                HomeWidgetInstance(
                    id: "home.missing",
                    definitionID: "missing.widget",
                    preferredWidth: ExactRational(1, 2),
                    preferredRows: 2
                )
            ]
        )
        let placed = placedHomeWidgets(
            layout: layout,
            definitions: builtInWidgetDefinitions(),
            contentWidth: 1376
        )
        XCTAssertEqual(placed.map(\.id), ["home.favorite-addons"])
    }

    func test_missingLayout_paintsTheDefaultAndDoesNotCreateAFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("home-layout.json")
        let store = HomeLayoutStore(fileURL: file)

        let layout = loadHomeLayout(from: store)

        XCTAssertEqual(layout, defaultHomeLayout())
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func test_newerLayout_isWithheldAndTheFileStays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("home-layout.json")
        let original = Data("{\"schemaVersion\":99,\"instances\":[]}".utf8)
        try original.write(to: file)

        let layout = loadHomeLayout(from: HomeLayoutStore(fileURL: file))

        XCTAssertNil(layout)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}
