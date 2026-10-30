import Foundation
import Yams

/// Cheap, in-process format detection for the Convert blocks. Never spawns an addon.
public enum FormatDetector {
    // MARK: text

    /// Most specific format that parses, strict before loose: JSON, XML/HTML, Markdown table, TSV, CSV, YAML, plain.
    /// Ambiguous text can guess wrong; the input override dropdown exists for that.
    public static func detectText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "plain" }
        if isJSON(trimmed) { return "json" }
        if trimmed.hasPrefix("<") {
            let head = trimmed.prefix(64).lowercased()
            if head.hasPrefix("<!doctype html") || head.hasPrefix("<html") { return "html" }
            if isXML(trimmed) { return "xml" }
        }
        let lines = trimmed.split(whereSeparator: \.isNewline).map(String.init)
        if lines.count >= 2 {
            if isMarkdownTable(lines) { return "markdown-table" }
            if isDelimited(lines, delimiter: "\t") { return "tsv" }
            if isDelimited(lines, delimiter: ",") { return "csv" }
        }
        if isYAMLCollection(trimmed) { return "yaml" }
        return "plain"
    }

    private static func isJSON(_ text: String) -> Bool {
        guard text.hasPrefix("{") || text.hasPrefix("["), let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func isXML(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return XMLParser(data: data).parse()
    }

    private static func isMarkdownTable(_ lines: [String]) -> Bool {
        guard lines[0].contains("|") else { return false }
        let separator = lines[1].trimmingCharacters(in: .whitespaces)
        guard separator.contains("-"), separator.contains("|") else { return false }
        return separator.allSatisfy { "|-: ".contains($0) }
    }

    /// Every line has the same field count (>1), with commas inside double quotes not counted.
    private static func isDelimited(_ lines: [String], delimiter: Character) -> Bool {
        let counts = lines.map { fieldCount($0, delimiter: delimiter) }
        guard let first = counts.first, first > 1 else { return false }
        return counts.allSatisfy { $0 == first }
    }

    private static func fieldCount(_ line: String, delimiter: Character) -> Int {
        var inQuotes = false
        var count = 1
        for ch in line {
            if ch == "\"" { inQuotes.toggle() } else if ch == delimiter, !inQuotes { count += 1 }
        }
        return count
    }

    private static func isYAMLCollection(_ text: String) -> Bool {
        guard let loaded = try? Yams.load(yaml: text) else { return false }
        return loaded is [String: Any] || loaded is [Any]
    }

    // MARK: files

    /// Magic bytes win over the extension when both exist and disagree; the extension decides otherwise.
    public static func detectFile(at url: URL, formats: [FormatDecl]) -> String? {
        let ext = url.pathExtension.lowercased()
        let byExtension = ext.isEmpty ? nil : formats.first { $0.extensions.contains(ext) }?.id
        if let magic = magicFormat(at: url), formats.contains(where: { $0.id == magic }) {
            return magic
        }
        return byExtension
    }

    private struct Signature {
        let format: String
        let bytes: [UInt8]
        var offset = 0
    }

    private static func ascii(_ text: String) -> [UInt8] {
        Array(text.utf8)
    }

    /// First match wins. Order matters only where signatures share a prefix (RIFF, ftyp).
    private static let signatures: [Signature] = [
        Signature(format: "png", bytes: [0x89, 0x50, 0x4E, 0x47]),
        Signature(format: "jpeg", bytes: [0xFF, 0xD8, 0xFF]),
        Signature(format: "gif", bytes: ascii("GIF8")),
        Signature(format: "pdf", bytes: ascii("%PDF")),
        Signature(format: "tiff", bytes: [0x49, 0x49, 0x2A, 0x00]),
        Signature(format: "tiff", bytes: [0x4D, 0x4D, 0x00, 0x2A]),
        Signature(format: "caf", bytes: ascii("caff")),
        Signature(format: "webp", bytes: ascii("WEBP"), offset: 8),
        Signature(format: "wav", bytes: ascii("WAVE"), offset: 8),
        Signature(format: "aiff", bytes: ascii("AIFF"), offset: 8),
        Signature(format: "heic", bytes: ascii("heic"), offset: 8),
        Signature(format: "heic", bytes: ascii("heix"), offset: 8),
        Signature(format: "heic", bytes: ascii("heim"), offset: 8),
        Signature(format: "heic", bytes: ascii("heis"), offset: 8),
        Signature(format: "heic", bytes: ascii("mif1"), offset: 8),
        Signature(format: "m4a", bytes: ascii("M4A"), offset: 8),
        Signature(format: "mp3", bytes: ascii("ID3")),
        Signature(format: "mp3", bytes: [0xFF, 0xFB])
    ]

    /// A container prefix that must also be present before an offset signature counts.
    private static let containers: [String: (bytes: [UInt8], offset: Int)] = [
        "webp": (ascii("RIFF"), 0), "wav": (ascii("RIFF"), 0), "aiff": (ascii("FORM"), 0),
        "heic": (ascii("ftyp"), 4), "m4a": (ascii("ftyp"), 4)
    ]

    private static func magicFormat(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let head = [UInt8](handle.readData(ofLength: 16))
        func has(_ bytes: [UInt8], at offset: Int) -> Bool {
            head.count >= offset + bytes.count && Array(head[offset ..< offset + bytes.count]) == bytes
        }
        return signatures.first { sig in
            guard has(sig.bytes, at: sig.offset) else { return false }
            guard let container = containers[sig.format] else { return true }
            return has(container.bytes, at: container.offset)
        }?.format
    }
}
