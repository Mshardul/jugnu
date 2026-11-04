import CoreGraphics
import ImageIO
@testable import JugnuCore
import UniformTypeIdentifiers
import XCTest

final class FormatDetectorRealFilesTests: XCTestCase {
    private var dir = URL(fileURLWithPath: "/")
    private var formats: [FormatDecl] {
        FormatCatalog.core + [
            FormatDecl(id: "docx", label: "Word", extensions: ["docx"]),
            FormatDecl(id: "rtf", label: "RTF", extensions: ["rtf"]),
            FormatDecl(id: "odt", label: "ODT", extensions: ["odt"])
        ]
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { [dir] in try? FileManager.default.removeItem(at: dir) }
    }

    @discardableResult
    private func run(_ tool: String, _ args: [String]) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func png() throws -> URL {
        let url = dir.appendingPathComponent("src.png")
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let type = UTType.png.identifier as CFString
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil))
        try CGImageDestinationAddImage(dest, XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    func testImagesAreDetectedEvenWithMisleadingExtensions() throws {
        let source = try png()
        for (format, name) in [("jpeg", "jpeg"), ("tiff", "tiff"), ("gif", "gif"), ("heic", "heic")] {
            let out = dir.appendingPathComponent("photo.\(name)")
            XCTAssertTrue(try run("/usr/bin/sips", ["-s", "format", format, source.path, "--out", out.path]), format)
            XCTAssertEqual(FormatDetector.detectFile(at: out, formats: formats), format)
            // wrong extension: content wins
            let renamed = dir.appendingPathComponent("liar-\(name).txt")
            try FileManager.default.copyItem(at: out, to: renamed)
            XCTAssertEqual(FormatDetector.detectFile(at: renamed, formats: formats), format, "magic over extension")
        }
        XCTAssertEqual(FormatDetector.detectFile(at: source, formats: formats), "png")
    }

    func testAudioIsDetected() throws {
        var wav = Data("RIFF".utf8)
        let samples = Data(count: 800)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(36 + samples.count).littleEndian, Array.init))
        wav.append(Data("WAVEfmt ".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(8000).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16000).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian, Array.init))
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian, Array.init))
        wav.append(Data("data".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(samples.count).littleEndian, Array.init))
        wav.append(samples)
        let source = dir.appendingPathComponent("s.wav")
        try wav.write(to: source)
        XCTAssertEqual(FormatDetector.detectFile(at: source, formats: formats), "wav")
        for (format, fileType, data, ext) in [
            ("aiff", "AIFF", "BEI16", "aiff"), ("m4a", "m4af", "aac", "m4a"), ("caf", "caff", "LEI16", "caf")
        ] {
            let out = dir.appendingPathComponent("a.\(ext)")
            XCTAssertTrue(try run("/usr/bin/afconvert", ["-f", fileType, "-d", data, source.path, out.path]), format)
            XCTAssertEqual(FormatDetector.detectFile(at: out, formats: formats), format)
        }
    }

    func testDocumentsAreDetectedByExtension() throws {
        let html = dir.appendingPathComponent("d.html")
        try "<html><body><p>Hi</p></body></html>".write(to: html, atomically: true, encoding: .utf8)
        XCTAssertEqual(FormatDetector.detectFile(at: html, formats: formats), "html")
        for format in ["docx", "rtf", "odt"] {
            let out = dir.appendingPathComponent("d.\(format)")
            XCTAssertTrue(try run("/usr/bin/textutil", ["-noload", "-convert", format, "-output", out.path, html.path]))
            XCTAssertEqual(FormatDetector.detectFile(at: out, formats: formats), format)
        }
        let text = dir.appendingPathComponent("n.txt")
        try "plain".write(to: text, atomically: true, encoding: .utf8)
        XCTAssertEqual(FormatDetector.detectFile(at: text, formats: formats), "plain")
    }
}
