import Foundation
import PDFKit

enum PDFFiles {
    static func open(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else {
            throw PDFToolError.unreadable
        }
        if document.isLocked {
            throw PDFToolError.locked
        }
        guard document.pageCount > 0 else {
            throw PDFToolError.unreadable
        }
        return document
    }

    static func pages(of document: PDFDocument) -> [PDFPage] {
        (0 ..< document.pageCount).compactMap { document.page(at: $0) }
    }

    static func copyPages(_ document: PDFDocument, indexes: [Int]) throws -> PDFDocument {
        let pages = indexes.compactMap { document.page(at: $0) }
        guard pages.count == indexes.count, !pages.isEmpty else {
            throw PDFToolError.unreadable
        }
        let copy = PDFDocument()
        for page in pages {
            copy.insert(page, at: copy.pageCount)
        }
        guard copy.pageCount == pages.count else {
            throw PDFToolError.unreadable
        }
        return copy
    }

    static func destination(beside source: URL, name: String, ext: String, fileManager: FileManager = .default) -> URL {
        let folder = source.deletingLastPathComponent()
        let suffix = ext.isEmpty ? "pdf" : ext
        var index = 1
        while true {
            let file = index == 1 ? "\(name).\(suffix)" : "\(name) \(index).\(suffix)"
            let candidate = folder.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    static func write(_ document: PDFDocument, to url: URL, options: [PDFDocumentWriteOption: Any] = [:]) throws {
        let wrote = options.isEmpty ? document.write(to: url) : document.write(to: url, withOptions: options)
        guard wrote, let written = PDFDocument(url: url), written.pageCount == document.pageCount, written.pageCount > 0 else {
            try? FileManager.default.removeItem(at: url)
            throw PDFToolError.writeFailed
        }
    }

    static func write(_ document: PDFDocument, beside source: URL, label: String) throws -> URL {
        let url = destination(beside: source, name: label, ext: "pdf")
        try write(document, to: url)
        return url
    }

    static func byteCount(_ url: URL) -> Int {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }

    static func versionDescription(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 16)
        let header = data.prefix { $0 >= 32 && $0 < 127 }
        guard let text = String(data: Data(header), encoding: .ascii), text.hasPrefix("%PDF-") else {
            return nil
        }
        let version = text.dropFirst(5).prefix { $0 != "\n" && $0 != "\r" && $0 != " " }
        guard !version.isEmpty else {
            return nil
        }
        return "PDF \(version)"
    }

    static func splitLabel(pages: [Int]) -> String {
        let numbers = pages.map { $0 + 1 }
        guard let first = numbers.first else {
            return "pages"
        }
        if numbers.count == 1 {
            return "page \(first)"
        }
        if let last = numbers.last, first <= last, numbers == Array(first ... last) {
            return "pages \(first)-\(last)"
        }
        return "pages " + numbers.map(String.init).joined(separator: ",")
    }
}
