import Foundation
import PDFKit

enum PDFJobs {
    static func merge(_ urls: [URL]) throws -> URL {
        guard urls.count >= 2, let first = urls.first else {
            throw PDFToolError.needsTwoPDFs
        }
        let result = PDFDocument()
        for url in urls {
            let document = try PDFFiles.open(url)
            for page in PDFFiles.pages(of: document) {
                result.insert(page, at: result.pageCount)
            }
        }
        guard result.pageCount > 0 else {
            throw PDFToolError.unreadable
        }
        let stem = first.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(result, beside: first, label: "\(stem) (merged)")
    }

    static func split(_ url: URL, ranges: String) throws -> [URL] {
        let document = try PDFFiles.open(url)
        let groups = try splitGroups(ranges, pageCount: document.pageCount)
        let stem = url.deletingPathExtension().lastPathComponent
        let snapshot = PDFFiles.pages(of: document)
        var saved: [URL] = []
        for group in groups {
            let piece = PDFDocument()
            for index in group {
                guard snapshot.indices.contains(index) else {
                    throw PDFToolError.badPages
                }
                piece.insert(snapshot[index], at: piece.pageCount)
            }
            let label = "\(stem) (\(PDFFiles.splitLabel(pages: group)))"
            saved.append(try PDFFiles.write(piece, beside: url, label: label))
        }
        return saved
    }

    static func extract(_ url: URL, pages: String) throws -> URL {
        let document = try PDFFiles.open(url)
        let indexes = try PageList.indexes(in: pages, pageCount: document.pageCount)
        guard !indexes.isEmpty else {
            throw PDFToolError.needsPages
        }
        let copy = try PDFFiles.copyPages(document, indexes: indexes)
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(copy, beside: url, label: "\(stem) (\(PDFFiles.splitLabel(pages: indexes)))")
    }

    static func organize(_ url: URL, order: String) throws -> URL {
        let document = try PDFFiles.open(url)
        if order.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PDFToolError.badOrder
        }
        let indexes = try PageList.permutation(order, pageCount: document.pageCount)
        let copy = try PDFFiles.copyPages(document, indexes: indexes)
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(copy, beside: url, label: "\(stem) (organized)")
    }

    static func rotate(_ url: URL, degreesText: String, pagesText: String) throws -> URL {
        let document = try PDFFiles.open(url)
        let degrees = try PageList.degrees(degreesText)
        let selected = try selectedPages(pagesText, pageCount: document.pageCount)
        let copy = try PDFFiles.copyPages(document, indexes: Array(0 ..< document.pageCount))
        for index in selected {
            guard let page = copy.page(at: index) else {
                throw PDFToolError.unreadable
            }
            var rotation = (page.rotation + degrees) % 360
            if rotation < 0 {
                rotation += 360
            }
            page.rotation = rotation
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(copy, beside: url, label: "\(stem) (rotated)")
    }

    static func pageCount(_ url: URL) throws -> Int {
        try PDFFiles.open(url).pageCount
    }

    static func info(_ url: URL) throws -> String {
        let document = try PDFFiles.open(url)
        let name = url.lastPathComponent
        let pages = document.pageCount
        let pageWord = pages == 1 ? "page" : "pages"
        let size = formattedBytes(PDFFiles.byteCount(url))
        var message = "\(name) has \(pages) \(pageWord) and is \(size)."
        message += document.isEncrypted ? " It is encrypted." : " It is not encrypted."
        if let version = PDFFiles.versionDescription(url) {
            message += " \(version)."
        }
        return message
    }

    static func extractText(_ url: URL) throws -> String {
        let document = try PDFFiles.open(url)
        return PDFFiles.pages(of: document).compactMap { $0.string }.joined(separator: "\n")
    }

    static func pageNumbers(_ url: URL, startText: String, pagesText: String) throws -> URL {
        let document = try PDFFiles.open(url)
        let start = try PageList.startNumber(startText)
        let selected = try selectedPages(pagesText, pageCount: document.pageCount)
        let snapshot = PDFFiles.pages(of: document)
        let result = PDFDocument()
        var stamped = 0
        for (index, page) in snapshot.enumerated() {
            if selected.contains(index) {
                guard let rendered = PDFRaster.stampedDocument(page, label: String(start + stamped)),
                      let numbered = rendered.page(at: 0)
                else {
                    throw PDFToolError.writeFailed
                }
                stamped += 1
                result.insert(numbered, at: result.pageCount)
            } else {
                result.insert(page, at: result.pageCount)
            }
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(result, beside: url, label: "\(stem) (numbered)")
    }

    static func flatten(_ url: URL) throws -> URL {
        let document = try PDFFiles.open(url)
        guard PDFFiles.pages(of: document).contains(where: hasWidget) else {
            throw PDFToolError.noForms
        }
        let result = PDFDocument()
        for page in PDFFiles.pages(of: document) {
            guard let rendered = PDFRaster.redrawnDocument(page), let redrawn = rendered.page(at: 0) else {
                throw PDFToolError.writeFailed
            }
            result.insert(redrawn, at: result.pageCount)
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(result, beside: url, label: "\(stem) (flat)")
    }

    static func grayscale(_ url: URL) throws -> URL {
        let document = try PDFFiles.open(url)
        let result = PDFDocument()
        for page in PDFFiles.pages(of: document) {
            guard let rendered = PDFRaster.grayscaleDocument(page), let gray = rendered.page(at: 0) else {
                throw PDFToolError.writeFailed
            }
            result.insert(gray, at: result.pageCount)
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(result, beside: url, label: "\(stem) (grayscale)")
    }

    static func compress(_ url: URL, qualityText: String) throws -> URL {
        let quality = try PDFCompressQuality.parse(qualityText)
        let document = try PDFFiles.open(url)
        let copy = try PDFFiles.copyPages(document, indexes: Array(0 ..< document.pageCount))
        let stem = url.deletingPathExtension().lastPathComponent
        let output = PDFFiles.destination(beside: url, name: "\(stem) (compressed)", ext: "pdf")
        try PDFFiles.write(copy, to: output, options: quality.options)
        if PDFFiles.byteCount(output) >= PDFFiles.byteCount(url) {
            try? FileManager.default.removeItem(at: output)
            throw PDFToolError.notSmaller
        }
        return output
    }

    static func jpegPDF(_ urls: [URL]) throws -> URL {
        guard let first = urls.first else {
            throw PDFToolError.needsImages
        }
        let result = PDFDocument()
        for url in urls {
            let image = try PDFRaster.loadImage(at: url)
            guard let rendered = PDFRaster.imageDocument(image), let page = rendered.page(at: 0) else {
                throw PDFToolError.writeFailed
            }
            result.insert(page, at: result.pageCount)
        }
        let stem = first.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(result, beside: first, label: stem)
    }

    static func export(_ url: URL, format: PDFImageFormat) throws -> [URL] {
        let document = try PDFFiles.open(url)
        let snapshot = PDFFiles.pages(of: document)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = format == .jpeg ? "jpg" : "png"
        var saved: [URL] = []
        for (index, page) in snapshot.enumerated() {
            guard let image = PDFRaster.render(page) else {
                throw PDFToolError.writeFailed
            }
            let name = snapshot.count == 1 ? stem : "\(stem) (page \(index + 1))"
            let output = PDFFiles.destination(beside: url, name: name, ext: ext)
            try PDFRaster.write(image, to: output, format: format)
            saved.append(output)
        }
        return saved
    }

    static func widgetCount(_ document: PDFDocument) -> Int {
        PDFFiles.pages(of: document).reduce(0) { count, page in
            count + page.annotations.filter(isWidget).count
        }
    }

    private static func splitGroups(_ text: String, pageCount: Int) throws -> [[Int]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return (0 ..< pageCount).map { [$0] }
        }
        return try PageList.rejectingOverlap(PageList.groups(in: trimmed, pageCount: pageCount))
    }

    private static func selectedPages(_ text: String, pageCount: Int) throws -> Set<Int> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Set(0 ..< pageCount)
        }
        return Set(try PageList.indexes(in: trimmed, pageCount: pageCount))
    }

    private static func hasWidget(_ page: PDFPage) -> Bool {
        page.annotations.contains(where: isWidget)
    }

    private static func isWidget(_ annotation: PDFAnnotation) -> Bool {
        annotation.type == "Widget"
    }

    private static func formattedBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) bytes"
        }
        if bytes < 1024 * 1024 {
            return "\(bytes / 1024) KB"
        }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}

enum PDFCompressQuality {
    case low
    case medium
    case high

    var options: [PDFDocumentWriteOption: Any] {
        switch self {
        case .low:
            [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true]
        case .medium:
            [.optimizeImagesForScreenOption: true]
        case .high:
            [.saveImagesAsJPEGOption: true]
        }
    }

    static func parse(_ text: String) throws -> PDFCompressQuality {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "low":
            .low
        case "medium":
            .medium
        case "high":
            .high
        default:
            throw PDFToolError.badQuality
        }
    }
}
