import CoreGraphics
import XCTest
@testable import WindowLayoutCore

final class GeometryTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1440, height: 900)

    func testLeftHalfUsesLeftOfVisibleFrame() {
        let rect = LayoutGeometry.rect(for: .leftHalf, visible: visible)
        XCTAssertEqual(rect.minX, 100, accuracy: 0.5)
        XCTAssertEqual(rect.width, 720, accuracy: 0.5)
        XCTAssertEqual(rect.height, 900, accuracy: 0.5)
    }

    func testNormalizeRoundTrip() {
        let original = CGRect(x: 100, y: 50, width: 720, height: 900)
        let norm = NormalizedRect.from(original, in: visible)
        let back = norm.denormalized(in: visible)
        XCTAssertEqual(back.minX, original.minX, accuracy: 0.5)
        XCTAssertEqual(back.width, original.width, accuracy: 0.5)
    }

    func testCenterStaysInsideVisible() {
        let rect = LayoutGeometry.rect(for: .center, visible: visible)
        XCTAssertTrue(visible.contains(CGPoint(x: rect.minX, y: rect.minY)))
        XCTAssertTrue(visible.contains(CGPoint(x: rect.maxX - 1, y: rect.maxY - 1)))
    }

    func testTileTwoSwap() {
        let front = CGRect.zero
        let other = CGRect.zero
        let swapped = LayoutGeometry.tileTwo(front: front, other: other, visible: visible, swap: true)
        XCTAssertEqual(swapped.0.minX, visible.midX, accuracy: 0.5)
        XCTAssertEqual(swapped.1.minX, visible.minX, accuracy: 0.5)
    }
}

final class ZoneStoreTests: XCTestCase {
    func testSeventhSaveThrowsFull() throws {
        var store = ZoneStore(zones: (1 ... 6).map { Zone(id: "\($0)", name: "Z\($0)", slots: []) })
        XCTAssertTrue(store.isFull)
        XCTAssertThrowsError(try store.save(Zone(id: "7", name: "Z7", slots: []))) { error in
            XCTAssertEqual(error as? ZoneStoreError, .full)
        }
    }

    func testReplaceDoesNotGrowPastSix() throws {
        var store = ZoneStore(zones: (1 ... 6).map { Zone(id: "\($0)", name: "Z\($0)", slots: []) })
        try store.save(Zone(id: "x", name: "Desk", slots: []), replacing: "3")
        XCTAssertEqual(store.zones.count, 6)
        XCTAssertEqual(store.zone(id: "3")?.name, "Desk")
    }
}

final class ZoneSavePlanTests: XCTestCase {
    func testFullStoreWithoutReplaceAsksWhichZone() {
        let store = ZoneStore(zones: (1 ... 6).map { Zone(id: "\($0)", name: "Z\($0)", slots: []) })
        let plan = ZoneSavePlanner.plan(store: store, name: "Desk", replaceId: nil)
        guard case let .pickReplacement(zones) = plan else {
            return XCTFail("expected replace picker")
        }
        XCTAssertEqual(zones.count, 6)
    }

    func testNamedSaveWhenNotFullCommits() {
        let store = ZoneStore()
        XCTAssertEqual(ZoneSavePlanner.plan(store: store, name: "Desk", replaceId: nil), .commit(name: "Desk", replacing: nil))
    }

    func testMissingNameAsksForName() {
        let store = ZoneStore()
        XCTAssertEqual(ZoneSavePlanner.plan(store: store, name: nil, replaceId: nil), .askName)
    }
}

final class ZoneCaptureTests: XCTestCase {
    func testSlotsKeepDisplayUUIDAndNormalizedFrame() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let windows = [
            LiveWindow(frame: CGRect(x: 0, y: 0, width: 500, height: 800), displayUUID: "main", visible: visible),
        ]
        let slots = ZoneCapture.slots(from: windows)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].displayUUID, "main")
        XCTAssertEqual(slots[0].norm.w, 0.5, accuracy: 0.01)
    }
}

final class DesktopLabelsTests: XCTestCase {
    func testRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        var labels = DesktopLabels()
        labels.bySpaceId["3"] = "Code"
        try DesktopLabelsIO.save(labels, to: url)
        let loaded = try DesktopLabelsIO.load(from: url)
        XCTAssertEqual(loaded.bySpaceId["3"], "Code")
    }
}

final class AddonWireTests: XCTestCase {
    func testSuccessUsesOkKey() throws {
        let json = AddonWire.encode(ok: true, message: "Moved window")
        XCTAssertTrue(json.contains("\"ok\":true"))
        XCTAssertTrue(json.contains("Moved window"))
    }
}
