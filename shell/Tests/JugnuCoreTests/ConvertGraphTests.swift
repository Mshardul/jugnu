@testable import JugnuCore
import XCTest

final class ConvertGraphTests: XCTestCase {
    private func manifest(
        _ id: String,
        converters: [ConverterEdge] = [],
        formats: [FormatDecl] = []
    ) -> AddonManifest {
        AddonManifest(
            id: id,
            name: id,
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            converters: converters,
            formats: formats
        )
    }

    private func edge(
        _ command: String,
        _ from: String,
        _ to: String,
        _ modes: [ConvertMode] = [.text]
    ) -> ConverterEdge {
        ConverterEdge(command: command, from: from, to: to, modes: modes)
    }

    func testTargetsAreOneHopAndFilteredByMode() {
        let graph = ConvertGraph(manifests: [
            manifest("jugnu.clip-tools", converters: [
                edge("json-csv", "json", "csv"),
                edge("json-yaml", "json", "yaml", [.text, .file]),
                edge("csv-json", "csv", "json")
            ]),
            manifest("jugnu.images", converters: [edge("heic-jpeg", "heic", "jpeg", [.file])])
        ])
        XCTAssertEqual(graph.targets(from: "json", mode: .text).map(\.id), ["csv", "yaml"])
        XCTAssertEqual(graph.targets(from: "json", mode: .file).map(\.id), ["yaml"])
        XCTAssertEqual(graph.targets(from: "heic", mode: .file).map(\.id), ["jpeg"])
        XCTAssertEqual(graph.targets(from: "heic", mode: .text), [])
    }

    func testNoChaining() {
        let graph = ConvertGraph(manifests: [
            manifest("a.one", converters: [edge("x", "json", "csv"), edge("y", "csv", "yaml")])
        ])
        // json → csv → yaml is two hops; yaml is not offered from json.
        XCTAssertEqual(graph.targets(from: "json", mode: .text).map(\.id), ["csv"])
        XCTAssertNil(graph.route(from: "json", to: "yaml", mode: .text))
    }

    func testSameEdgeFromTwoAddonsKeepsAddonOrder() {
        let graph = ConvertGraph(manifests: [
            manifest("first.addon", converters: [edge("a", "json", "csv")]),
            manifest("second.addon", converters: [edge("b", "json", "csv")])
        ])
        XCTAssertEqual(graph.targets(from: "json", mode: .text).map(\.id), ["csv"])
        let providers = graph.routes(from: "json", to: "csv", mode: .text).map(\.addonID)
        XCTAssertEqual(providers, ["first.addon", "second.addon"])
        XCTAssertEqual(graph.route(from: "json", to: "csv", mode: .text)?.command, "a")
    }

    func testDisabledAddonRemovesItsRoutes() {
        let clip = manifest("jugnu.clip-tools", converters: [edge("json-csv", "json", "csv")])
        XCTAssertEqual(ConvertGraph(manifests: [clip]).targets(from: "json", mode: .text).count, 1)
        XCTAssertEqual(ConvertGraph(manifests: []).targets(from: "json", mode: .text), [])
    }

    func testAddonFormatsJoinTheCatalogAndFirstDeclarationWins() {
        let first = FormatDecl(id: "ndjson", label: "NDJSON", extensions: ["ndjson"])
        let second = FormatDecl(id: "ndjson", label: "Other", extensions: ["jsonl"])
        let graph = ConvertGraph(manifests: [
            manifest("a.one", converters: [edge("x", "json", "ndjson")], formats: [first]),
            manifest("b.two", formats: [second])
        ])
        XCTAssertEqual(graph.format(id: "ndjson")?.label, "NDJSON")
        XCTAssertEqual(graph.targets(from: "json", mode: .text).map(\.label), ["NDJSON"])
    }

    func testCoreFormatsCannotBeOverriddenByAddons() {
        let impostor = FormatDecl(id: "json", label: "Impostor", extensions: ["json"])
        let graph = ConvertGraph(manifests: [manifest("a.one", formats: [impostor])])
        XCTAssertEqual(graph.format(id: "json")?.label, "JSON")
    }

    func testSourcesListOnlyFormatsThatCanBeConverted() {
        let graph = ConvertGraph(manifests: [
            manifest("a.one", converters: [edge("x", "json", "csv"), edge("y", "heic", "jpeg", [.file])])
        ])
        XCTAssertEqual(graph.sources(mode: .text).map(\.id), ["json"])
        XCTAssertEqual(graph.sources(mode: .file).map(\.id), ["heic"])
    }

    func testRouteWithUndeclaredFormatIsIgnoredInTargets() {
        let graph = ConvertGraph(manifests: [
            manifest("a.one", converters: [edge("x", "json", "mystery")])
        ])
        XCTAssertEqual(graph.targets(from: "json", mode: .text), [])
    }

    func testShippedClipToolsManifestFeedsTheGraph() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let clip = try ManifestLoader.load(from: repoRoot.appendingPathComponent("addons/jugnu.clip-tools"))
        let graph = ConvertGraph(manifests: [clip])
        func targets(_ from: String, _ mode: ConvertMode) -> Set<String> {
            Set(graph.targets(from: from, mode: mode).map(\.id))
        }
        XCTAssertTrue(targets("json", .text).isSuperset(of: ["csv", "yaml", "tsv", "xml", "markdown-table"]))
        XCTAssertTrue(targets("csv", .text).isSuperset(of: ["json", "tsv", "markdown-table"]))
        XCTAssertTrue(targets("xml", .text).contains("json"))
        XCTAssertTrue(targets("yaml", .text).contains("json"))
        XCTAssertEqual(targets("json", .text), targets("json", .file))
        XCTAssertEqual(graph.targets(from: "heic", mode: .file), [])
    }
}

final class ShippedConverterCatalogTests: XCTestCase {
    private func shippedManifests() throws -> [AddonManifest] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let addons = repoRoot.appendingPathComponent("addons")
        let names = try FileManager.default.contentsOfDirectory(atPath: addons.path).sorted()
        return try names.filter { $0.hasPrefix("jugnu.") }.map {
            try ManifestLoader.load(from: addons.appendingPathComponent($0))
        }
    }

    func testEveryShippedManifestLoadsAndFeedsOneGraph() throws {
        let manifests = try shippedManifests()
        let graph = ConvertGraph(manifests: manifests.filter { !$0.entrypoint.isShell })
        // every declared edge resolves to formats the graph knows (core or addon-declared)
        for route in graph.routes {
            XCTAssertNotNil(graph.format(id: route.from), "\(route.addonID):\(route.command) from \(route.from)")
            XCTAssertNotNil(graph.format(id: route.to), "\(route.addonID):\(route.command) to \(route.to)")
        }
    }

    func testTheImportantConversionsAreOffered() throws {
        let graph = try ConvertGraph(manifests: shippedManifests().filter { !$0.entrypoint.isShell })
        func has(_ from: String, _ to: String, _ mode: ConvertMode) -> Bool {
            graph.route(from: from, to: to, mode: mode) != nil
        }
        // data
        for pair in [("json", "csv"), ("csv", "json"), ("json", "yaml"), ("yaml", "json"), ("xml", "json"),
                     ("json", "xml"), ("json", "tsv"), ("csv", "tsv"), ("csv", "markdown-table"),
                     ("markdown-table", "json"), ("markdown", "html"), ("html", "markdown"), ("html", "plain")]
        {
            XCTAssertTrue(has(pair.0, pair.1, .text), "text \(pair)")
            XCTAssertTrue(has(pair.0, pair.1, .file), "file \(pair)")
        }
        // images, audio, documents, pdf: file only
        for pair in [("heic", "jpeg"), ("png", "jpeg"), ("jpeg", "png"), ("tiff", "png"), ("png", "heic"),
                     ("wav", "m4a"), ("m4a", "wav"), ("aiff", "wav"), ("mp3", "wav"), ("wav", "caf"),
                     ("docx", "plain"), ("rtf", "docx"), ("html", "docx"), ("odt", "docx"), ("plain", "rtf"),
                     ("jpeg", "pdf"), ("png", "pdf"), ("pdf", "plain")]
        {
            XCTAssertTrue(has(pair.0, pair.1, .file), "file \(pair)")
            XCTAssertFalse(has(pair.0, pair.1, .text) && !["html", "plain"].contains(pair.1), "no text \(pair)")
        }
        XCTAssertEqual(graph.format(id: "docx")?.label, "Word (DOCX)")
    }

    func testDroppedFilesOfEachFamilyGetOutputChoices() throws {
        let graph = try ConvertGraph(manifests: shippedManifests().filter { !$0.entrypoint.isShell })
        XCTAssertEqual(
            Set(graph.targets(from: "heic", mode: .file).map(\.id)), ["jpeg", "png"]
        )
        XCTAssertTrue(graph.targets(from: "docx", mode: .file).map(\.id).contains("plain"))
        XCTAssertTrue(graph.targets(from: "wav", mode: .file).map(\.id).contains("m4a"))
        XCTAssertEqual(graph.targets(from: "pdf", mode: .file).map(\.id), ["plain"])
    }
}
