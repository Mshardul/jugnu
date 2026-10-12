import CoreGraphics
import CoreText
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import PDFToolsCore

final class PDFToolsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-tools-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_pageList_parsesRangesAndRejectsOverlap() throws {
        XCTAssertEqual(try PageList.indexes(in: "1, 3-4", pageCount: 4), [0, 2, 3])
        XCTAssertEqual(try PageList.groups(in: "1-2, 4", pageCount: 4), [[0, 1], [3]])
        XCTAssertThrowsError(try PageList.rejectingOverlap([[0, 1], [1]])) { error in
            XCTAssertEqual(error as? PDFToolError, .overlap)
        }
        XCTAssertThrowsError(try PageList.permutation("1, 1", pageCount: 2)) { error in
            XCTAssertEqual(error as? PDFToolError, .badOrder)
        }
        XCTAssertEqual(try PageList.permutation("2, 1", pageCount: 2), [1, 0])
    }

    func test_merge_keepsOrderAndLeavesOriginals() throws {
        let first = try writePDF(named: "A.pdf", rotations: [0])
        let second = try writePDF(named: "B.pdf", rotations: [90])
        let merged = try PDFJobs.merge([first, second])
        let document = try XCTUnwrap(PDFDocument(url: merged))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertEqual(document.page(at: 1)?.rotation, 90)
        XCTAssertEqual(PDFDocument(url: first)?.pageCount, 1)
        XCTAssertEqual(merged.lastPathComponent, "A (merged).pdf")
    }

    func test_lockedPDF_isNotRewritten() throws {
        let locked = try writePDF(named: "Secret.pdf", rotations: [0], userPassword: "secret")
        XCTAssertThrowsError(try PDFJobs.pageCount(locked)) { error in
            XCTAssertEqual(error as? PDFToolError, .locked)
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Secret (merged).pdf").path
        ))
    }

    func test_splitExtractAndOrganize_writeCopies() throws {
        let source = try writePDF(named: "Report.pdf", rotations: [0, 90, 180])
        let parts = try PDFJobs.split(source, ranges: "1-2, 3")
        XCTAssertEqual(parts.map(\.lastPathComponent), ["Report (pages 1-2).pdf", "Report (page 3).pdf"])
        XCTAssertEqual(PDFDocument(url: parts[0])?.pageCount, 2)

        let extracted = try PDFJobs.extract(source, pages: "3, 1")
        let extractDoc = try XCTUnwrap(PDFDocument(url: extracted))
        XCTAssertEqual(extractDoc.pageCount, 2)
        XCTAssertEqual(extractDoc.page(at: 0)?.rotation, 180)
        XCTAssertEqual(extractDoc.page(at: 1)?.rotation, 0)

        let organized = try PDFJobs.organize(source, order: "3, 1, 2")
        XCTAssertEqual(PDFDocument(url: organized)?.page(at: 0)?.rotation, 180)
        XCTAssertEqual(PDFDocument(url: source)?.page(at: 0)?.rotation, 0)
    }

    func test_rotate_addsDegreesOnTheCopy() throws {
        let source = try writePDF(named: "Report.pdf", rotations: [0, 0])
        let rotated = try PDFJobs.rotate(source, degreesText: "90", pagesText: "2")
        let document = try XCTUnwrap(PDFDocument(url: rotated))
        XCTAssertEqual(document.page(at: 0)?.rotation, 0)
        XCTAssertEqual(document.page(at: 1)?.rotation, 90)
        XCTAssertEqual(PDFDocument(url: source)?.page(at: 1)?.rotation, 0)
    }

    func test_infoAndText_describeTheFile() throws {
        let source = try writeTextPDF(named: "Notes.pdf", text: "Hello pages")
        let info = try PDFJobs.info(source)
        XCTAssertTrue(info.contains("Notes.pdf has 1 page"))
        XCTAssertTrue(info.contains("not encrypted"))
        XCTAssertTrue(info.contains("PDF 1."))
        XCTAssertEqual(try PDFJobs.extractText(source).contains("Hello pages"), true)
    }

    func test_pageNumbers_stampTheCopy() throws {
        let source = try writePDF(named: "Report.pdf", rotations: [0, 0])
        let numbered = try PDFJobs.pageNumbers(source, startText: "3", pagesText: "")
        let document = try XCTUnwrap(PDFDocument(url: numbered))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertEqual(document.page(at: 0)?.string?.contains("3"), true)
        XCTAssertEqual(document.page(at: 1)?.string?.contains("4"), true)
    }

    func test_bookmarks_addAndEditOnACopy() throws {
        let source = try writeOutlinedPDF(named: "Report.pdf", title: "Intro")
        let state = directory.appendingPathComponent("state", isDirectory: true)
        let listed = PDFToolsSession.run(
            command: "bookmarks",
            fields: [:],
            paths: [source],
            itemId: nil,
            stateDirectory: state
        )
        XCTAssertTrue(listed.contains("Intro"))
        XCTAssertTrue(listed.contains("\"pattern\":\"list\""))

        let form = PDFToolsSession.run(
            command: "bookmarks",
            fields: [:],
            paths: [],
            itemId: "0",
            stateDirectory: state
        )
        XCTAssertTrue(form.contains("\"pattern\":\"form\""))
        XCTAssertTrue(form.contains("Intro"))

        let saved = PDFToolsSession.run(
            command: "bookmarks",
            fields: ["title": "Start", "page": "1"],
            paths: [],
            itemId: nil,
            stateDirectory: state
        )
        XCTAssertTrue(saved.contains("Report (bookmarks).pdf"))
        let copy = try XCTUnwrap(PDFDocument(url: directory.appendingPathComponent("Report (bookmarks).pdf")))
        XCTAssertEqual(copy.outlineRoot?.child(at: 0)?.label, "Start")
        XCTAssertEqual(PDFDocument(url: source)?.outlineRoot?.child(at: 0)?.label, "Intro")
    }

    func test_flatten_dropsFormFields() throws {
        let source = try writeFormPDF(named: "Form.pdf")
        XCTAssertGreaterThan(PDFJobs.widgetCount(try XCTUnwrap(PDFDocument(url: source))), 0)
        let flat = try PDFJobs.flatten(source)
        XCTAssertEqual(PDFJobs.widgetCount(try XCTUnwrap(PDFDocument(url: flat))), 0)
        XCTAssertGreaterThan(PDFJobs.widgetCount(try XCTUnwrap(PDFDocument(url: source))), 0)
    }

    func test_plainPDF_hasNoFormsToFlatten() throws {
        let source = try writePDF(named: "Plain.pdf", rotations: [0])
        XCTAssertThrowsError(try PDFJobs.flatten(source)) { error in
            XCTAssertEqual(error as? PDFToolError, .noForms)
        }
    }

    func test_grayscale_rewritesPagesAsGray() throws {
        let source = try writeRedPDF(named: "Red.pdf")
        let gray = try PDFJobs.grayscale(source)
        let page = try XCTUnwrap(PDFDocument(url: gray)?.page(at: 0))
        let image = try XCTUnwrap(PDFRaster.render(page))
        let pixel = try centerPixel(of: image)
        XCTAssertEqual(pixel.red, pixel.green, accuracy: 2)
        XCTAssertEqual(pixel.green, pixel.blue, accuracy: 2)
        XCTAssertGreaterThan(pixel.red, 20)
        XCTAssertLessThan(pixel.red, 200)
    }

    func test_compress_leavesATextPDFUntouched() throws {
        let source = try writeTextPDF(named: "Notes.pdf", text: "Hello")
        XCTAssertThrowsError(try PDFJobs.compress(source, qualityText: "medium")) { error in
            XCTAssertEqual(error as? PDFToolError, .notSmaller)
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Notes (compressed).pdf").path
        ))
    }

    func test_jpegRoundTrip_writesAPDFAndImages() throws {
        let jpeg = try writeJPEG(named: "Dot.jpg")
        let pdf = try PDFJobs.jpegPDF([jpeg])
        XCTAssertEqual(PDFDocument(url: pdf)?.pageCount, 1)
        XCTAssertEqual(pdf.lastPathComponent, "Dot.pdf")
        let images = try PDFJobs.export(pdf, format: .png)
        XCTAssertEqual(images.map(\.pathExtension), ["png"])
        XCTAssertNotNil(CGImageSourceCreateWithURL(images[0] as CFURL, nil))
    }

    func test_session_splitFormThenBlankRanges() throws {
        let source = try writePDF(named: "Report.pdf", rotations: [0, 90])
        let state = directory.appendingPathComponent("state", isDirectory: true)
        let form = PDFToolsSession.run(
            command: "split",
            fields: [:],
            paths: [source],
            itemId: nil,
            stateDirectory: state
        )
        XCTAssertTrue(form.contains("\"pattern\":\"form\""))
        let done = PDFToolsSession.run(
            command: "split",
            fields: ["ranges": ""],
            paths: [],
            itemId: nil,
            stateDirectory: state
        )
        XCTAssertTrue(done.contains("Saved 2 PDFs next to the original."))
        XCTAssertEqual(PDFDocument(url: source)?.pageCount, 2)
    }

    private func writePDF(named name: String, rotations: [Int], userPassword: String? = nil) throws -> URL {
        let document = PDFDocument()
        for rotation in rotations {
            let page = PDFPage()
            page.rotation = rotation
            document.insert(page, at: document.pageCount)
        }
        let url = directory.appendingPathComponent(name)
        if let userPassword {
            XCTAssertTrue(document.write(to: url, withOptions: [
                .userPasswordOption: userPassword,
                .ownerPasswordOption: userPassword,
            ]))
        } else {
            XCTAssertTrue(document.write(to: url))
        }
        return url
    }

    private func writeTextPDF(named name: String, text: String) throws -> URL {
        var box = CGRect(x: 0, y: 0, width: 240, height: 120)
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1),
        ]
        let attributed = try XCTUnwrap(CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary))
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: 24, y: 60)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
        let url = directory.appendingPathComponent(name)
        try (data as Data).write(to: url)
        return url
    }

    private func writeRedPDF(named name: String) throws -> URL {
        var box = CGRect(x: 0, y: 0, width: 40, height: 40)
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(box)
        context.endPDFPage()
        context.closePDF()
        let url = directory.appendingPathComponent(name)
        try (data as Data).write(to: url)
        return url
    }

    private func writeFormPDF(named name: String) throws -> URL {
        let document = PDFDocument()
        let page = PDFPage()
        let annotation = PDFAnnotation(
            bounds: CGRect(x: 40, y: 40, width: 120, height: 24),
            forType: .widget,
            withProperties: nil
        )
        annotation.widgetFieldType = .text
        annotation.widgetStringValue = "Ada"
        page.addAnnotation(annotation)
        document.insert(page, at: 0)
        let url = directory.appendingPathComponent(name)
        XCTAssertTrue(document.write(to: url))
        return url
    }

    private func writeOutlinedPDF(named name: String, title: String) throws -> URL {
        let document = PDFDocument()
        let page = PDFPage()
        document.insert(page, at: 0)
        let root = PDFOutline()
        let item = PDFOutline()
        item.label = title
        item.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: 700))
        root.insertChild(item, at: 0)
        document.outlineRoot = root
        let url = directory.appendingPathComponent(name)
        XCTAssertTrue(document.write(to: url))
        return url
    }

    private func writeJPEG(named name: String) throws -> URL {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try XCTUnwrap(context.makeImage())
        let url = directory.appendingPathComponent(name)
        try PDFRaster.write(image, to: url, format: .jpeg)
        return url
    }

    private func centerPixel(of image: CGImage) throws -> (red: Int, green: Int, blue: Int) {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = ((height / 2) * width + width / 2) * 4
        return (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
    }
}
