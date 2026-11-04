@testable import JugnuCore
import XCTest

final class ConvertFilePlanTests: XCTestCase {
    private var dir = URL(fileURLWithPath: "/")

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { [dir] in try? FileManager.default.removeItem(at: dir) }
    }

    private func file(_ name: String, _ body: String = "x") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func graph() -> ConvertGraph {
        func edge(_ command: String, _ from: String, _ to: String) -> ConverterEdge {
            ConverterEdge(command: command, from: from, to: to, modes: [.file])
        }
        let manifest = AddonManifest(
            id: "jugnu.clip-tools",
            name: "Clip",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            converters: [edge("json-csv", "json", "csv"), edge("json-yaml", "json", "yaml")]
        )
        return ConvertGraph(manifests: [manifest])
    }

    func testSingleJSONFileOffersTargets() throws {
        let plan = try ConvertFilePlan.make(files: [file("a.json")], chosenTarget: nil, graph: graph())
        XCTAssertEqual(plan.source, "json")
        XCTAssertEqual(plan.targets.map(\.id), ["csv", "yaml"])
        XCTAssertEqual(plan.route?.command, "json-csv")
        XCTAssertNil(plan.problem)
    }

    func testKeepsChosenTarget() throws {
        let plan = try ConvertFilePlan.make(files: [file("a.json")], chosenTarget: "yaml", graph: graph())
        XCTAssertEqual(plan.route?.command, "json-yaml")
    }

    func testMixedFormatsAreRefused() throws {
        let plan = try ConvertFilePlan.make(
            files: [file("a.json"), file("b.csv")], chosenTarget: nil, graph: graph()
        )
        XCTAssertEqual(plan.problem, .mixedFormats)
        XCTAssertNil(plan.route)
    }

    func testUnrecognizedFileIsReported() throws {
        let odd = try file("a.zzz")
        let plan = ConvertFilePlan.make(files: [odd], chosenTarget: nil, graph: graph())
        XCTAssertEqual(plan.problem, .unrecognized(odd))
    }

    func testFormatWithNoFileConversionsSaysSo() throws {
        let plan = try ConvertFilePlan.make(files: [file("a.csv")], chosenTarget: nil, graph: graph())
        XCTAssertEqual(plan.problem, .noConversions(format: "csv"))
        XCTAssertEqual(plan.source, "csv")
    }

    func testNoFiles() {
        XCTAssertEqual(ConvertFilePlan.make(files: [], chosenTarget: nil, graph: graph()).problem, .noFiles)
    }
}
