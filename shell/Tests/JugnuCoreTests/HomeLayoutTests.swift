@testable import JugnuCore
import XCTest

final class HomeLayoutTests: XCTestCase {
    func test_defaultHome_placesFavoritesRecentAndUpdates() {
        let layout = defaultHomeLayout()
        XCTAssertEqual(layout.schemaVersion, HomeLayoutSchema.supported)
        XCTAssertEqual(layout.instances.map(\.definitionID), [
            BuiltInWidget.favoriteAddons,
            BuiltInWidget.recentActivity,
            BuiltInWidget.updates
        ])
        XCTAssertEqual(layout.instances.map(\.preferredWidth), [
            ExactRational(1, 2), ExactRational(1, 2), ExactRational(1, 2)
        ])
        XCTAssertEqual(layout.instances.map(\.preferredRows), [3, 3, 2])
        XCTAssertFalse(layout.instances.contains { $0.definitionID == BuiltInWidget.runningWork })
    }

    func test_builtInDefinitions_acceptTheOneColumnFallback() {
        let issues = builtInWidgetDefinitions().flatMap(widgetDefinitionIssues)
        XCTAssertEqual(issues, [])
    }

    func test_definition_withoutAOneColumnStructure_isRejected() {
        let definition = WidgetDefinition(
            id: "wide-only",
            name: "Wide",
            limits: WidgetSpanLimits(minColumns: 3, maxColumns: 6, minRows: 1, maxRows: 2),
            defaultWidth: ExactRational(1, 2),
            defaultRows: 1,
            rendersInOneColumn: false
        )
        XCTAssertEqual(widgetDefinitionIssues(definition), [.oneColumnFallbackUnsupported])
    }

    func test_roundTrip_preservesOrderAndWidth() throws {
        let original = defaultHomeLayout()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HomeLayoutSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_newerSchema_isLeftUntouched() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("home-layout.json")
        let original = Data("{\"schemaVersion\":99,\"instances\":[{\"future\":true}]}".utf8)
        try original.write(to: file)

        let store = HomeLayoutStore(fileURL: file)
        let result = try store.mutate { snapshot in
            snapshot.instances = []
        }

        XCTAssertEqual(result, .leftUntouched)
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertEqual(store.read(), .newer(schemaVersion: 99))
    }

    func test_unreadableFile_isLeftUntouched() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("home-layout.json")
        let original = Data("not json".utf8)
        try original.write(to: file)

        let store = HomeLayoutStore(fileURL: file)
        XCTAssertEqual(try store.mutate { $0.instances = [] }, .leftUntouched)
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertEqual(store.read(), .unreadable)
    }

    func test_missingFile_mutateWritesTheEditedDefault() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("home-layout.json")
        let store = HomeLayoutStore(fileURL: file)

        XCTAssertEqual(store.read(), .missing)
        XCTAssertEqual(try store.mutate { $0.instances.removeLast() }, .written)

        guard case let .ready(layout) = store.read() else {
            return XCTFail("expected a written layout")
        }
        XCTAssertEqual(layout.instances.map(\.definitionID), [
            BuiltInWidget.favoriteAddons,
            BuiltInWidget.recentActivity
        ])
    }

    func test_rationalDecode_reducesAndRejectsZero() throws {
        let data = Data("{\"numerator\":2,\"denominator\":4}".utf8)
        let rational = try JSONDecoder().decode(ExactRational.self, from: data)
        XCTAssertEqual(rational, ExactRational(1, 2))

        let zero = Data("{\"numerator\":1,\"denominator\":0}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ExactRational.self, from: zero))
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
