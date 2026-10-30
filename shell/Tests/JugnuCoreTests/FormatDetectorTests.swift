@testable import JugnuCore
import XCTest

final class FormatDetectorTests: XCTestCase {
    func testDetectsJSON() {
        XCTAssertEqual(FormatDetector.detectText("{\"a\": 1}"), "json")
        XCTAssertEqual(FormatDetector.detectText("  [1, 2, 3]\n"), "json")
    }

    func testBrokenJSONIsNotJSON() {
        XCTAssertNotEqual(FormatDetector.detectText("{\"a\": "), "json")
    }

    func testBareNumberAndStringArePlain() {
        XCTAssertEqual(FormatDetector.detectText("42"), "plain")
        XCTAssertEqual(FormatDetector.detectText("hello world"), "plain")
    }

    func testDetectsXMLAndHTML() {
        XCTAssertEqual(FormatDetector.detectText("<root><a>1</a></root>"), "xml")
        XCTAssertEqual(FormatDetector.detectText("<!DOCTYPE html><html><body></body></html>"), "html")
    }

    func testDetectsCSVWithConsistentFields() {
        XCTAssertEqual(FormatDetector.detectText("name,age\nada,36\nlin,41"), "csv")
    }

    func testCSVQuotedCommasDoNotBreakFieldCount() {
        XCTAssertEqual(FormatDetector.detectText("name,note\nada,\"a, b\"\nlin,x"), "csv")
    }

    func testRaggedLinesAreNotCSV() {
        XCTAssertNotEqual(FormatDetector.detectText("a,b,c\nd,e"), "csv")
    }

    func testSingleLineIsNotCSV() {
        XCTAssertEqual(FormatDetector.detectText("a,b,c"), "plain")
    }

    func testDetectsTSV() {
        XCTAssertEqual(FormatDetector.detectText("a\tb\n1\t2"), "tsv")
    }

    func testDetectsMarkdownTable() {
        XCTAssertEqual(FormatDetector.detectText("| a | b |\n|---|---|\n| 1 | 2 |"), "markdown-table")
    }

    func testDetectsYAMLCollections() {
        XCTAssertEqual(FormatDetector.detectText("name: ada\nage: 36"), "yaml")
        XCTAssertEqual(FormatDetector.detectText("- a\n- b"), "yaml")
    }

    func testEmptyIsPlain() {
        XCTAssertEqual(FormatDetector.detectText("  \n "), "plain")
    }

    // MARK: files

    private func tempFile(_ name: String, bytes: [UInt8]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    func testFileDetectedByExtension() throws {
        let url = try tempFile("data.JSON", bytes: Array("{}".utf8))
        XCTAssertEqual(FormatDetector.detectFile(at: url, formats: FormatCatalog.core), "json")
    }

    func testMagicBytesWinOverDisagreeingExtension() throws {
        let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]
        let url = try tempFile("photo.jpg", bytes: png)
        XCTAssertEqual(FormatDetector.detectFile(at: url, formats: FormatCatalog.core), "png")
    }

    func testMagicBytesWhenExtensionMissing() throws {
        let url = try tempFile("scan", bytes: Array("%PDF-1.7\n".utf8))
        XCTAssertEqual(FormatDetector.detectFile(at: url, formats: FormatCatalog.core), "pdf")
    }

    func testHEICBrand() throws {
        var bytes: [UInt8] = [0, 0, 0, 0x18]
        bytes += Array("ftypheic".utf8)
        let url = try tempFile("IMG_1", bytes: bytes)
        XCTAssertEqual(FormatDetector.detectFile(at: url, formats: FormatCatalog.core), "heic")
    }

    func testUnknownFileIsNil() throws {
        let url = try tempFile("mystery.zzz", bytes: [1, 2, 3])
        XCTAssertNil(FormatDetector.detectFile(at: url, formats: FormatCatalog.core))
    }

    func testAddonDeclaredExtensionIsDetected() throws {
        let url = try tempFile("rows.ndjson", bytes: Array("{}\n".utf8))
        let formats = FormatCatalog.core + [FormatDecl(id: "ndjson", label: "NDJSON", extensions: ["ndjson"])]
        XCTAssertEqual(FormatDetector.detectFile(at: url, formats: formats), "ndjson")
    }
}
