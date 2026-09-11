import XCTest
import JugnuCore

final class AddonConfigResolverTests: XCTestCase {
    func testMissingFileUsesDefaults() throws {
        let schema = [
            AddonConfigField(key: "default_interval_minutes", type: .int, default: .number(30)),
            AddonConfigField(key: "show_nudge_now_in_manage", type: .bool, default: .bool(true)),
        ]
        let url = URL(fileURLWithPath: "/tmp/jugnu-config-missing-\(UUID().uuidString).yaml")
        let resolved = try AddonConfigResolver.resolve(schema: schema, fileURL: url)
        XCTAssertEqual(resolved["default_interval_minutes"], .number(30))
        XCTAssertEqual(resolved["show_nudge_now_in_manage"], .bool(true))
    }

    func testUnknownKeyBlocks() throws {
        let schema = [AddonConfigField(key: "show_nudge_now_in_manage", type: .bool, default: .bool(true))]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cfg-\(UUID().uuidString).yaml")
        try "typo_key: true\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try AddonConfigResolver.resolve(schema: schema, fileURL: url)) { error in
            XCTAssertEqual(error as? AddonConfigError, .unknownKey("typo_key"))
        }
    }

    func testMergeOverridesDefault() throws {
        let schema = [AddonConfigField(key: "default_interval_minutes", type: .int, default: .number(30))]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cfg-\(UUID().uuidString).yaml")
        try "default_interval_minutes: 12\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let resolved = try AddonConfigResolver.resolve(schema: schema, fileURL: url)
        XCTAssertEqual(resolved["default_interval_minutes"], .number(12))
    }

    func testEmptySchemaReturnsEmpty() throws {
        let url = URL(fileURLWithPath: "/tmp/never")
        let resolved = try AddonConfigResolver.resolve(schema: [], fileURL: url)
        XCTAssertTrue(resolved.isEmpty)
    }

    func testSyntaxErrorBlocks() throws {
        let schema = [AddonConfigField(key: "show_nudge_now_in_manage", type: .bool, default: .bool(true))]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cfg-\(UUID().uuidString).yaml")
        try ":\n  - broken\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try AddonConfigResolver.resolve(schema: schema, fileURL: url)) { error in
            XCTAssertEqual(error as? AddonConfigError, .syntaxError)
        }
    }

    func testInvalidValueBlocks() throws {
        let schema = [AddonConfigField(key: "default_interval_minutes", type: .int, default: .number(30))]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cfg-\(UUID().uuidString).yaml")
        try "default_interval_minutes: \"nope\"\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try AddonConfigResolver.resolve(schema: schema, fileURL: url)) { error in
            guard case let .invalidValue(key, _)? = error as? AddonConfigError else {
                return XCTFail("expected invalidValue, got \(error)")
            }
            XCTAssertEqual(key, "default_interval_minutes")
        }
    }

    func testTemplateYAMLIncludesDefaults() {
        let schema = [
            AddonConfigField(key: "show_nudge_now_in_manage", type: .bool, default: .bool(true)),
            AddonConfigField(
                key: "ai_difficulty",
                type: .enum,
                values: ["easy", "medium"],
                default: .string("medium")
            ),
        ]
        let yaml = AddonConfigResolver.templateYAML(schema: schema)
        XCTAssertTrue(yaml.contains("show_nudge_now_in_manage: true"))
        XCTAssertTrue(yaml.contains("ai_difficulty: medium"))
    }
}
