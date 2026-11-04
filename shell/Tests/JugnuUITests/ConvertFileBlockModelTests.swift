import AppKit
import JugnuCore
@testable import JugnuUI
import XCTest

@MainActor
final class ConvertFileBlockModelTests: XCTestCase {
    private var dir = URL(fileURLWithPath: "/")

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { [dir] in try? FileManager.default.removeItem(at: dir) }
    }

    private func file(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try "x".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func graph() -> ConvertGraph {
        let manifest = AddonManifest(
            id: "jugnu.clip-tools",
            name: "Clip",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            converters: [
                ConverterEdge(command: "json-csv", from: "json", to: "csv", modes: [.file]),
                ConverterEdge(command: "json-yaml", from: "json", to: "yaml", modes: [.file])
            ]
        )
        return ConvertGraph(manifests: [manifest])
    }

    func testConvertsEachFileInOrderWithTargetExtension() async throws {
        let seen = Box()
        let model = ConvertFileBlockModel(graph: graph()) { input, _, ext in
            await seen.append("\(input.lastPathComponent)>\(ext)")
            return input.deletingPathExtension().appendingPathExtension(ext)
        }
        try model.setFiles([file("a.json"), file("b.json")])
        XCTAssertTrue(model.canConvert)
        await model.convert()
        let calls = await seen.items
        XCTAssertEqual(calls, ["a.json>csv", "b.json>csv"])
        XCTAssertEqual(model.results.count, 2)
        XCTAssertFalse(model.isConverting)
    }

    func testOneFailureDoesNotStopTheRest() async throws {
        let model = ConvertFileBlockModel(graph: graph()) { input, _, ext in
            if input.lastPathComponent == "a.json" {
                throw ConvertClientError.failed("Bad file.")
            }
            return input.deletingPathExtension().appendingPathExtension(ext)
        }
        try model.setFiles([file("a.json"), file("b.json")])
        await model.convert()
        XCTAssertEqual(model.results.first?.outcome, .failed("Bad file."))
        if case .saved = model.results.last?.outcome {} else {
            XCTFail("second file should convert")
        }
    }

    func testMixedFormatsCannotConvert() throws {
        let model = ConvertFileBlockModel(graph: graph()) { input, _, _ in input }
        try model.setFiles([file("a.json"), file("b.csv")])
        XCTAssertFalse(model.canConvert)
        XCTAssertEqual(model.plan.problem, .mixedFormats)
    }

    func testChosenTargetPicksRoute() throws {
        let model = ConvertFileBlockModel(graph: graph()) { input, _, _ in input }
        try model.setFiles([file("a.json")])
        model.chosenTarget = "yaml"
        XCTAssertEqual(model.plan.route?.command, "json-yaml")
    }

    func testAddFilesDeduplicates() throws {
        let model = ConvertFileBlockModel(graph: graph()) { input, _, _ in input }
        let first = try file("a.json")
        model.setFiles([first])
        try model.addFiles([first, file("b.json")])
        XCTAssertEqual(model.plan.files.count, 2)
    }

    private func imageGraph() -> ConvertGraph {
        ConvertGraph(manifests: [AddonManifest(
            id: "jugnu.images",
            name: "Images",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            converters: [ConverterEdge(command: "png-jpeg", from: "png", to: "jpeg", modes: [.file])]
        )])
    }

    private func pasteboardWithImage() throws -> NSPasteboard {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let tiff = try XCTUnwrap(rep.tiffRepresentation)
        let board = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        board.clearContents()
        board.setData(tiff, forType: .tiff)
        addTeardownBlock { board.releaseGlobally() }
        return board
    }

    func testClipboardImageIsStagedAsPNGAndCleanedAfterConvert() async throws {
        let seen = Box()
        let model = ConvertFileBlockModel(graph: imageGraph()) { input, _, _ in
            await seen.append(input.lastPathComponent)
            return input
        }
        try model.pasteFromClipboard(pasteboard: pasteboardWithImage())
        let staged = try XCTUnwrap(model.plan.files.first)
        XCTAssertTrue(ConvertFileBlockModel.isStaged(staged))
        XCTAssertEqual(model.plan.source, "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertTrue(model.canConvert)
        await model.convert()
        let calls = await seen.items
        XCTAssertEqual(calls, ["Clipboard image.png"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(model.results.count, 1)
    }

    func testReplacingStagedImageRemovesIt() throws {
        let model = ConvertFileBlockModel(graph: imageGraph()) { input, _, _ in input }
        try model.pasteFromClipboard(pasteboard: pasteboardWithImage())
        let staged = try XCTUnwrap(model.plan.files.first)
        try model.setFiles([file("a.json")])
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
    }

    func testEmptyClipboardLeavesNoFiles() {
        let board = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        addTeardownBlock { board.releaseGlobally() }
        board.clearContents()
        let model = ConvertFileBlockModel(graph: imageGraph()) { input, _, _ in input }
        model.pasteFromClipboard(pasteboard: board)
        XCTAssertEqual(model.plan.problem, .noFiles)
    }
}

private actor Box {
    var items: [String] = []
    func append(_ item: String) {
        items.append(item)
    }
}
