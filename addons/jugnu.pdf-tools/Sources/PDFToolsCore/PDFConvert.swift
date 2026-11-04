import Foundation
import PDFKit

/// Single-file conversions for the Convert addon (`op: convert`). The shell reserves `out`; this only writes into it.
public enum PDFConvert {
    /// Command id -> (from, to) format ids. Mirrors `converters:` in addon.yaml.
    public static let edges: [String: (from: String, to: String)] = [
        "jpg-pdf": ("jpeg", "pdf"),
        "png-pdf": ("png", "pdf"),
        "extract-text": ("pdf", "plain"),
    ]

    /// Returns the JSON reply: `{"ok":true,"path":…}` or `{"ok":false,"error":…}`.
    public static func run(command: String, from: String?, to: String?, path: String?, out: String?) -> String {
        guard let edge = edges[command] else {
            return PDFJSON.fail("Unknown converter: \(command)")
        }
        guard from == edge.from, to == edge.to else {
            return PDFJSON.fail("\(command) converts \(edge.from) to \(edge.to).")
        }
        guard let path, let out, path.hasPrefix("/"), out.hasPrefix("/") else {
            return PDFJSON.fail("Paths must be absolute.")
        }
        let input = URL(fileURLWithPath: path)
        let output = URL(fileURLWithPath: out)
        do {
            if edge.from == "pdf" {
                try writeText(of: input, to: output)
            } else {
                try writePDF(fromImage: input, to: output)
            }
            return PDFJSON.encodeOK(path: out)
        } catch let error as PDFToolError {
            return PDFJSON.fail(PDFToolsSession.message(for: error, file: input))
        } catch {
            return PDFJSON.fail(PDFToolsSession.message(for: .writeFailed, file: input))
        }
    }

    private static func writePDF(fromImage input: URL, to output: URL) throws {
        let image = try PDFRaster.loadImage(at: input)
        guard let document = PDFRaster.imageDocument(image), document.write(to: output) else {
            throw PDFToolError.writeFailed
        }
    }

    private static func writeText(of input: URL, to output: URL) throws {
        let text = try PDFJobs.extractText(input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw PDFToolError.noText
        }
        do {
            try (text + "\n").write(to: output, atomically: false, encoding: .utf8)
        } catch {
            throw PDFToolError.writeFailed
        }
    }
}
