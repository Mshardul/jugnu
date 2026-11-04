@testable import JugnuCore
import XCTest

final class ConvertTextPlanTests: XCTestCase {
    private func graph() -> ConvertGraph {
        func edge(_ command: String, _ from: String, _ to: String) -> ConverterEdge {
            ConverterEdge(command: command, from: from, to: to, modes: [.text])
        }
        let manifest = AddonManifest(
            id: "jugnu.clip-tools",
            name: "Clip",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            converters: [
                edge("json-csv", "json", "csv"),
                edge("json-yaml", "json", "yaml"),
                edge("csv-json", "csv", "json")
            ]
        )
        return ConvertGraph(manifests: [manifest])
    }

    func testDetectsAndPicksFirstTarget() {
        let plan = ConvertTextPlan.make(text: #"{"a":1}"#, sourceOverride: nil, chosenTarget: nil, graph: graph())
        XCTAssertEqual(plan.detected, "json")
        XCTAssertEqual(plan.source, "json")
        XCTAssertEqual(plan.targets.map(\.id), ["csv", "yaml"])
        XCTAssertEqual(plan.target, "csv")
        XCTAssertEqual(plan.route?.command, "json-csv")
    }

    func testKeepsChosenTargetWhileStillOffered() {
        let plan = ConvertTextPlan.make(text: #"{"a":1}"#, sourceOverride: nil, chosenTarget: "yaml", graph: graph())
        XCTAssertEqual(plan.target, "yaml")
        XCTAssertEqual(plan.route?.command, "json-yaml")
    }

    func testDropsChosenTargetWhenSourceChanges() {
        let plan = ConvertTextPlan.make(text: "a,b\n1,2", sourceOverride: nil, chosenTarget: "yaml", graph: graph())
        XCTAssertEqual(plan.source, "csv")
        XCTAssertEqual(plan.target, "json")
    }

    func testOverrideBeatsDetection() {
        let plan = ConvertTextPlan.make(text: "a,b\n1,2", sourceOverride: "json", chosenTarget: nil, graph: graph())
        XCTAssertEqual(plan.detected, "csv")
        XCTAssertEqual(plan.source, "json")
        XCTAssertEqual(plan.route?.command, "json-csv")
    }

    func testNoConversionForUnconvertibleSource() {
        let plan = ConvertTextPlan.make(text: "just words", sourceOverride: nil, chosenTarget: "csv", graph: graph())
        XCTAssertEqual(plan.source, "plain")
        XCTAssertEqual(plan.targets, [])
        XCTAssertNil(plan.target)
        XCTAssertNil(plan.route)
    }

    func testEmptyInputHasNoRoute() {
        let plan = ConvertTextPlan.make(text: "", sourceOverride: nil, chosenTarget: nil, graph: graph())
        XCTAssertNil(plan.route)
    }
}
