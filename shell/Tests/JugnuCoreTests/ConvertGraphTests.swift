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
        XCTAssertEqual(graph.targets(from: "json", mode: .text).map(\.id), ["csv", "yaml"])
        XCTAssertEqual(graph.targets(from: "csv", mode: .text).map(\.id), ["json"])
        XCTAssertEqual(graph.targets(from: "xml", mode: .text).map(\.id), ["json"])
        XCTAssertEqual(graph.targets(from: "yaml", mode: .text).map(\.id), ["json"])
        XCTAssertEqual(graph.targets(from: "json", mode: .file), [])
    }
}
