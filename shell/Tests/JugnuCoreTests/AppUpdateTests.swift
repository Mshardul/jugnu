@testable import JugnuCore
import XCTest

final class AppUpdateTests: XCTestCase {
    private let newer = AppRegistryEntry(
        id: "jugnu.shell",
        name: "Jugnu",
        version: "0.2.0",
        minMacOS: "14.0",
        url: "https://github.com/Mshardul/jugnu/releases/download/shell-v0.2.0/Jugnu-0.2.0.zip",
        sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    )

    func testNewerIsAvailable() {
        let result = AppUpdate.availability(running: "0.1.0", registry: newer, osMajor: 14, osMinor: 0)
        XCTAssertEqual(result, .available(newer))
    }

    func testSameIsUpToDate() {
        let same = AppRegistryEntry(
            id: newer.id, name: newer.name, version: "0.1.0", minMacOS: newer.minMacOS,
            url: newer.url, sha256: newer.sha256
        )
        XCTAssertEqual(
            AppUpdate.availability(running: "0.1.0", registry: same, osMajor: 14, osMinor: 0),
            .upToDate
        )
    }

    func testOlderRegistryIsUpToDate() {
        let older = AppRegistryEntry(
            id: newer.id, name: newer.name, version: "0.0.1", minMacOS: newer.minMacOS,
            url: newer.url, sha256: newer.sha256
        )
        XCTAssertEqual(
            AppUpdate.availability(running: "0.1.0", registry: older, osMajor: 14, osMinor: 0),
            .upToDate
        )
    }

    func testInvalidSemVerIsUpToDate() {
        let bad = AppRegistryEntry(
            id: newer.id, name: newer.name, version: "not-a-version", minMacOS: newer.minMacOS,
            url: newer.url, sha256: newer.sha256
        )
        XCTAssertEqual(
            AppUpdate.availability(running: "0.1.0", registry: bad, osMajor: 14, osMinor: 0),
            .upToDate
        )
        XCTAssertEqual(
            AppUpdate.availability(running: "dev", registry: newer, osMajor: 14, osMinor: 0),
            .upToDate
        )
    }

    func testMinMacOSBlocksNewer() {
        let high = AppRegistryEntry(
            id: newer.id, name: newer.name, version: newer.version, minMacOS: "15.0",
            url: newer.url, sha256: newer.sha256
        )
        XCTAssertEqual(
            AppUpdate.availability(running: "0.1.0", registry: high, osMajor: 14, osMinor: 5),
            .blockedMacOS(required: "15.0")
        )
    }
}
