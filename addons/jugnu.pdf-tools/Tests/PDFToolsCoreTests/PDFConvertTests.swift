import CoreGraphics
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import PDFToolsCore

final class PDFConvertTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-convert-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeImage(_ name: String, type: UTType) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func reply(_ json: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }

    func test_jpegAndPNGBecomeOnePagePDF() throws {
        for (command, from, name, type) in [
            ("jpg-pdf", "jpeg", "a.jpg", UTType.jpeg), ("png-pdf", "png", "a.png", UTType.png),
        ] {
            let source = try writeImage(name, type: type)
            let out = directory.appendingPathComponent("\(command).pdf")
            let result = reply(PDFConvert.run(
                command: command, from: from, to: "pdf", path: source.path, out: out.path
            ))
            XCTAssertEqual(result["ok"] as? Bool, true, "\(result)")
            XCTAssertEqual(PDFDocument(url: out)?.pageCount, 1)
        }
    }

    func test_pdfWithTextExtractsToPlainFile() throws {
        let pdf = directory.appendingPathComponent("t.pdf")
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 200, height: 100)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        let text = NSAttributedString(string: "Hello convert")
        let line = CTLineCreateWithAttributedString(text)
        context.textPosition = CGPoint(x: 10, y: 50)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: pdf)
        let out = directory.appendingPathComponent("t.txt")
        let result = reply(PDFConvert.run(
            command: "extract-text", from: "pdf", to: "plain", path: pdf.path, out: out.path
        ))
        XCTAssertEqual(result["ok"] as? Bool, true, "\(result)")
        XCTAssertTrue(try String(contentsOf: out, encoding: .utf8).contains("Hello"))
    }

    func test_refusalsAreOrdinaryErrors() throws {
        let source = try writeImage("a.png", type: .png)
        let out = directory.appendingPathComponent("o.pdf").path
        for bad in [
            PDFConvert.run(command: "rm", from: "png", to: "pdf", path: source.path, out: out),
            PDFConvert.run(command: "png-pdf", from: "jpeg", to: "pdf", path: source.path, out: out),
            PDFConvert.run(command: "png-pdf", from: "png", to: "pdf", path: "a.png", out: out),
            PDFConvert.run(command: "png-pdf", from: "png", to: "pdf", path: source.path, out: nil),
            PDFConvert.run(command: "png-pdf", from: "png", to: "pdf", path: "/nope/x.png", out: out),
        ] {
            let result = reply(bad)
            XCTAssertEqual(result["ok"] as? Bool, false, "\(result)")
            XCTAssertFalse((result["error"] as? String ?? "").isEmpty)
        }
    }

    func test_pdfWithoutTextIsPlainError() throws {
        let image = try writeImage("a.png", type: .png)
        let pdf = directory.appendingPathComponent("img.pdf")
        _ = PDFConvert.run(command: "png-pdf", from: "png", to: "pdf", path: image.path, out: pdf.path)
        let out = directory.appendingPathComponent("img.txt").path
        let result = reply(PDFConvert.run(command: "extract-text", from: "pdf", to: "plain", path: pdf.path, out: out))
        XCTAssertEqual(result["ok"] as? Bool, false)
        XCTAssertEqual(result["error"] as? String, "That PDF has no text to extract.")
    }
}
