@testable import JugnuCore
import XCTest

final class RegistryTrustTests: XCTestCase {
    private func entryJSON(trust: String?) -> Data {
        let field = trust.map { ",\"trust\":\"\($0)\"" } ?? ""
        return Data("""
        {"id":"jugnu.x","name":"X","version":"1.0.0","api":1,"url":"https://github.com/a.zip",
        "sha256":"ab","summary":"s","category":"System"\(field)}
        """.utf8)
    }

    func testKnownTiersDecode() throws {
        for (raw, tier) in [
            ("first-party", RegistryTrust.firstParty),
            ("verified", .verified),
            ("community", .community)
        ] {
            let entry = try JSONDecoder().decode(RegistryEntry.self, from: entryJSON(trust: raw))
            XCTAssertEqual(entry.trust, tier)
        }
    }

    func testMissingOrUnknownTierFallsToLowest() throws {
        for raw in [nil, "platinum", ""] {
            let entry = try JSONDecoder().decode(RegistryEntry.self, from: entryJSON(trust: raw))
            XCTAssertEqual(entry.trust, .community)
        }
    }

    func testIdPrefixDoesNotImplyTrust() throws {
        let entry = try JSONDecoder().decode(RegistryEntry.self, from: entryJSON(trust: nil))
        XCTAssertTrue(entry.id.hasPrefix("jugnu."))
        XCTAssertEqual(entry.trust, .community)
    }

    func testTierRoundTrips() throws {
        let entry = try JSONDecoder().decode(RegistryEntry.self, from: entryJSON(trust: "first-party"))
        let again = try JSONDecoder().decode(RegistryEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(again.trust, .firstParty)
    }

    func testShippedRegistryMarksEveryEntryFirstParty() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("registry/addons.json")
        let entries = try JSONDecoder().decode([RegistryEntry].self, from: Data(contentsOf: file))
        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.allSatisfy { $0.trust == .firstParty })
    }
}
