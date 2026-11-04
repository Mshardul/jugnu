import JugnuCore
@testable import JugnuUI
import XCTest

@MainActor
final class ConvertTextBlockModelTests: XCTestCase {
    private func graph() -> ConvertGraph {
        let manifest = AddonManifest(
            id: "jugnu.clip-tools",
            name: "Clip",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            converters: [
                ConverterEdge(command: "json-csv", from: "json", to: "csv", modes: [.text]),
                ConverterEdge(command: "json-yaml", from: "json", to: "yaml", modes: [.text])
            ]
        )
        return ConvertGraph(manifests: [manifest])
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(400))
    }

    func testConvertsDetectedInputAfterDebounce() async {
        let model = ConvertTextBlockModel(graph: graph()) { text, route in "\(route.command):\(text)" }
        model.input = #"{"a":1}"#
        XCTAssertEqual(model.output, "")
        await settle()
        XCTAssertEqual(model.output, #"json-csv:{"a":1}"#)
        XCTAssertNil(model.errorMessage)
    }

    func testLatestInputWins() async {
        let model = ConvertTextBlockModel(graph: graph()) { text, _ in text }
        model.input = #"{"a":1}"#
        model.input = #"{"a":2}"#
        await settle()
        XCTAssertEqual(model.output, #"{"a":2}"#)
    }

    func testChangingTargetReconverts() async {
        let model = ConvertTextBlockModel(graph: graph()) { _, route in route.to }
        model.input = #"{"a":1}"#
        await settle()
        XCTAssertEqual(model.output, "csv")
        model.chosenTarget = "yaml"
        await settle()
        XCTAssertEqual(model.output, "yaml")
    }

    func testAddonFailureShowsMessageAndClearsOutput() async {
        let model = ConvertTextBlockModel(graph: graph()) { _, _ in throw ConvertClientError.failed("Not valid JSON.") }
        model.input = #"{"a":1}"#
        await settle()
        XCTAssertEqual(model.errorMessage, "Not valid JSON.")
        XCTAssertEqual(model.output, "")
    }

    func testClearingInputClearsOutputAndError() async {
        let model = ConvertTextBlockModel(graph: graph()) { text, _ in text }
        model.input = #"{"a":1}"#
        await settle()
        model.input = ""
        XCTAssertEqual(model.output, "")
        XCTAssertNil(model.errorMessage)
    }

    func testDownloadWritesNewFileAndNeverOverwrites() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let revealed = RevealLog()
        let model = ConvertTextBlockModel(graph: graph(), downloads: dir,
                                          reveal: { revealed.urls.append($0) })
        { _, _ in
            "a,b"
        }
        model.input = #"{"a":1}"#
        await settle()
        model.downloadOutput()
        model.downloadOutput()
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        XCTAssertEqual(names, ["converted 2.csv", "converted.csv"])
        XCTAssertEqual(revealed.urls.map(\.lastPathComponent), ["converted.csv", "converted 2.csv"])
    }

    func testLockIsOnByDefault() {
        XCTAssertTrue(ConvertTextBlockModel(graph: graph()) { text, _ in text }.isReadOnly)
    }

    func testFailureKeepsLastGoodOutputDimmed() async {
        let fail = FailSwitch()
        let model = ConvertTextBlockModel(graph: graph()) { text, _ in
            if fail.on {
                throw ConvertClientError.failed("Not valid JSON.")
            }
            return "ok:\(text)"
        }
        model.input = #"{"a":1}"#
        await settle()
        XCTAssertFalse(model.isStale)
        fail.on = true
        model.input = #"{"a":"#
        await settle()
        XCTAssertEqual(model.output, #"ok:{"a":1}"#)
        XCTAssertTrue(model.isStale)
        XCTAssertEqual(model.errorMessage, "Not valid JSON.")
        fail.on = false
        model.input = #"{"a":2}"#
        await settle()
        XCTAssertFalse(model.isStale)
        XCTAssertEqual(model.output, #"ok:{"a":2}"#)
    }

    func testLargeInputSkipsLiveModeUntilConvertNow() async {
        let model = ConvertTextBlockModel(graph: graph()) { text, _ in "len:\(text.utf8.count)" }
        let big = "[" + String(repeating: "1,", count: ConvertTextBlockModel.liveInputLimit) + "1]"
        model.input = big
        await settle()
        XCTAssertTrue(model.isOverLiveLimit)
        XCTAssertEqual(model.output, "")
        model.convertNow()
        await settle()
        XCTAssertEqual(model.output, "len:\(big.utf8.count)")
    }

    func testEditsAreNotReplacedWithoutAsking() async {
        let model = ConvertTextBlockModel(graph: graph()) { text, _ in "out:\(text)" }
        model.input = #"{"a":1}"#
        await settle()
        model.isReadOnly = false
        model.output = "my edit"
        XCTAssertTrue(model.outputEdited)
        model.input = #"{"a":2}"#
        await settle()
        XCTAssertEqual(model.output, "my edit")
        XCTAssertEqual(model.pendingOutput, #"out:{"a":2}"#)
        model.keepEdits()
        XCTAssertNil(model.pendingOutput)
        XCTAssertEqual(model.output, "my edit")
        model.input = #"{"a":3}"#
        await settle()
        model.replaceEdits()
        XCTAssertEqual(model.output, #"out:{"a":3}"#)
        XCTAssertFalse(model.outputEdited)
    }

    func testUneditedOutputIsReplacedSilently() async {
        let model = ConvertTextBlockModel(graph: graph()) { text, _ in "out:\(text)" }
        model.input = #"{"a":1}"#
        await settle()
        model.input = #"{"a":2}"#
        await settle()
        XCTAssertNil(model.pendingOutput)
        XCTAssertEqual(model.output, #"out:{"a":2}"#)
    }
}

@MainActor
private final class RevealLog {
    var urls: [URL] = []
}

private final class FailSwitch: @unchecked Sendable {
    var on = false
}
