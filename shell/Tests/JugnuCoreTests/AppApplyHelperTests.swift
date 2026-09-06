@testable import JugnuCore
import XCTest

final class AppApplyHelperTests: XCTestCase {
    func testWritePlacesScriptOutsideDestAndRecordsPlan() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent("helper")
        let source = root.appendingPathComponent("staging/uuid/Jugnu.app")
        let dest = root.appendingPathComponent("Applications/Jugnu.app")

        let script = try AppApplyHelper.write(dir: dir, pid: 4242, sourceApp: source, destApp: dest)
        XCTAssertEqual(script.lastPathComponent, "apply.sh")
        XCTAssertTrue(script.path.hasPrefix(dir.path))
        XCTAssertFalse(script.path.hasPrefix(dest.path))

        let body = try String(contentsOf: script, encoding: .utf8)
        XCTAssertTrue(body.contains("ditto"))
        XCTAssertTrue(body.contains(dest.path))
        XCTAssertTrue(body.contains("kill -0"))
        XCTAssertTrue(body.contains("xattr -dr com.apple.quarantine"))
        XCTAssertTrue(body.contains("open "))

        let planData = try Data(contentsOf: dir.appendingPathComponent("plan.json"))
        let plan = try JSONDecoder().decode(HelperPlan.self, from: planData)
        XCTAssertEqual(plan.pid, 4242)
        XCTAssertEqual(plan.dest, dest.path)
        XCTAssertEqual(plan.source, source.path)
    }
}

private struct HelperPlan: Decodable {
    var pid: Int32
    var source: String
    var dest: String
}
