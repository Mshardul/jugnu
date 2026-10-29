@testable import JugnuCore
import XCTest

final class WidgetModelTests: XCTestCase {
    func test_unknownPrimitive_failsClosed() {
        XCTAssertEqual(widgetPrimitive(token: "text"), .text)
        XCTAssertEqual(widgetPrimitive(token: "listReorder"), .listReorder)
        XCTAssertEqual(widgetPrimitive(token: "script"), .unsupported)
        XCTAssertEqual(widgetPrimitive(token: "html"), .unsupported)
    }

    func test_clockValue_isMarkedShellOwned() {
        let value = WidgetValue(text: "12:00", clock: .civil)
        XCTAssertEqual(value.clock, .civil)
    }

    func test_staleIndicator_keepsCachedContentAndSkipsDisabled() {
        let stale = WidgetSnapshotRecord(
            instanceID: "a",
            fetchedAt: nil,
            failure: .timeout,
            hasContent: true
        )
        XCTAssertTrue(stale.showsStaleIndicator)
        let disabled = WidgetSnapshotRecord(
            instanceID: "a",
            fetchedAt: nil,
            failure: .disabled,
            hasContent: true
        )
        XCTAssertFalse(disabled.showsStaleIndicator)
        XCTAssertEqual(disabled.failure, .disabled)
    }

    func test_registryIndex_exposesNamePreviewAndCount() {
        let index = AddonWidgetIndex(
            addonID: "jugnu.clock",
            widgets: [
                RegistryWidgetSummary(name: "World Clock", staticPreview: "clock"),
                RegistryWidgetSummary(name: "Timer", staticPreview: "timer")
            ]
        )
        XCTAssertEqual(index.count, 2)
        XCTAssertEqual(index.widgets.map(\.name), ["World Clock", "Timer"])
        XCTAssertEqual(index.widgets.map(\.staticPreview), ["clock", "timer"])
    }

    func test_snapshotCache_isASeparateSchemaFromTheLayout() throws {
        XCTAssertNotEqual(WidgetSnapshotSchema.supported, 0)
        let cache = WidgetSnapshotCache(schemaVersion: WidgetSnapshotSchema.supported, records: [])
        let data = try JSONEncoder().encode(cache)
        XCTAssertEqual(try JSONDecoder().decode(WidgetSnapshotCache.self, from: data), cache)
    }
}
