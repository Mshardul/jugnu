import Foundation

struct PendingPDF: Codable, Equatable {
    var command: String
    var paths: [String]
    var bookmark: String?

    var urls: [URL] {
        paths.map { URL(fileURLWithPath: $0) }
    }

    static func file(in directory: URL) -> URL {
        directory.appendingPathComponent("pending-pdf")
    }

    static func load(directory: URL) -> PendingPDF? {
        guard let data = try? Data(contentsOf: file(in: directory)) else {
            return nil
        }
        return try? JSONDecoder().decode(PendingPDF.self, from: data)
    }

    func save(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.file(in: directory), options: .atomic)
    }

    static func clear(directory: URL) {
        try? FileManager.default.removeItem(at: file(in: directory))
    }
}

public enum PDFToolsSession {
    public static func isFollowUp(command: String, fields: [String: String], itemId: String?) -> Bool {
        if itemId != nil {
            return true
        }
        switch command {
        case "split":
            return fields["ranges"] != nil
        case "extract-pages":
            return fields["pages"] != nil
        case "organize":
            return fields["order"] != nil
        case "rotate":
            return fields["degrees"] != nil
        case "page-numbers":
            return fields["start"] != nil
        case "compress":
            return fields["quality"] != nil
        case "bookmarks":
            return fields["title"] != nil
        default:
            return false
        }
    }

    public static func run(
        command: String,
        fields: [String: String],
        paths: [URL],
        itemId: String?,
        stateDirectory: URL
    ) -> String {
        if !isFollowUp(command: command, fields: fields, itemId: itemId) {
            PendingPDF.clear(directory: stateDirectory)
        }
        switch command {
        case "merge":
            return merge(paths)
        case "split":
            return split(paths, fields: fields, state: stateDirectory)
        case "extract-pages":
            return extract(paths, fields: fields, state: stateDirectory)
        case "organize":
            return organize(paths, fields: fields, state: stateDirectory)
        case "rotate":
            return rotate(paths, fields: fields, state: stateDirectory)
        case "page-count":
            return pageCount(paths)
        case "page-numbers":
            return pageNumbers(paths, fields: fields, state: stateDirectory)
        case "bookmarks":
            return bookmarks(paths, fields: fields, itemId: itemId, state: stateDirectory)
        case "info":
            return info(paths)
        case "extract-text":
            return extractText(paths)
        case "compress":
            return compress(paths, fields: fields, state: stateDirectory)
        case "jpg-pdf":
            return jpegPDF(paths)
        case "pdf-jpg":
            return export(paths, format: .jpeg, kind: "JPEGs")
        case "pdf-png":
            return export(paths, format: .png, kind: "PNGs")
        case "flatten-forms":
            return flatten(paths)
        case "grayscale":
            return grayscale(paths)
        default:
            return PDFJSON.fail("Unknown command.")
        }
    }

    private static func merge(_ paths: [URL]) -> String {
        guard paths.count >= 2 else {
            return PDFJSON.fail(message(for: .needsTwoPDFs, file: nil))
        }
        for url in paths {
            if let failure = probe(url) {
                return failure
            }
        }
        return catching(paths[0]) {
            PDFJSON.ok(saved([try PDFJobs.merge(paths)], kind: "PDFs"))
        }
    }

    private static func split(_ paths: [URL], fields: [String: String], state: URL) -> String {
        guard let ranges = fields["ranges"] else {
            return offerForm(paths, command: "split", state: state) { url, count in
                PDFJSON.form(
                    title: "Split \(url.lastPathComponent)",
                    fields: [PDFJSON.textField(
                        id: "ranges",
                        label: "Ranges, or leave blank for each page. \(count) pages, like 1-3, 4-6.",
                        value: ""
                    )]
                )
            }
        }
        return writeOne(paths, command: "split", state: state) { url in
            saved(try PDFJobs.split(url, ranges: ranges), kind: "PDFs")
        }
    }

    private static func extract(_ paths: [URL], fields: [String: String], state: URL) -> String {
        guard let pages = fields["pages"] else {
            return offerForm(paths, command: "extract-pages", state: state) { url, count in
                PDFJSON.form(
                    title: "Extract pages from \(url.lastPathComponent)",
                    fields: [PDFJSON.textField(id: "pages", label: "Pages to keep, like 1, 3-5. \(count) pages.", value: "")]
                )
            }
        }
        return writeOne(paths, command: "extract-pages", state: state) { url in
            saved([try PDFJobs.extract(url, pages: pages)], kind: "PDFs")
        }
    }

    private static func organize(_ paths: [URL], fields: [String: String], state: URL) -> String {
        guard let order = fields["order"] else {
            return offerForm(paths, command: "organize", state: state) { url, count in
                PDFJSON.form(
                    title: "Reorder \(url.lastPathComponent)",
                    fields: [PDFJSON.textField(
                        id: "order",
                        label: "New order. Enter all \(count) pages once, like 3, 1, 2.",
                        value: ""
                    )]
                )
            }
        }
        return writeOne(paths, command: "organize", state: state) { url in
            saved([try PDFJobs.organize(url, order: order)], kind: "PDFs")
        }
    }

    private static func rotate(_ paths: [URL], fields: [String: String], state: URL) -> String {
        guard let degrees = fields["degrees"] else {
            return offerForm(paths, command: "rotate", state: state) { url, count in
                PDFJSON.form(
                    title: "Rotate \(url.lastPathComponent)",
                    fields: [
                        PDFJSON.textField(id: "degrees", label: "Degrees: 90, 180, or 270.", value: "90"),
                        PDFJSON.textField(id: "pages", label: "Pages, or leave blank for all \(count).", value: ""),
                    ]
                )
            }
        }
        let pages = fields["pages"] ?? ""
        return writeOne(paths, command: "rotate", state: state) { url in
            saved([try PDFJobs.rotate(url, degreesText: degrees, pagesText: pages)], kind: "PDFs")
        }
    }

    private static func pageNumbers(_ paths: [URL], fields: [String: String], state: URL) -> String {
        guard let start = fields["start"] else {
            return offerForm(paths, command: "page-numbers", state: state) { url, count in
                PDFJSON.form(
                    title: "Number pages in \(url.lastPathComponent)",
                    fields: [
                        PDFJSON.textField(id: "start", label: "First number.", value: "1"),
                        PDFJSON.textField(id: "pages", label: "Pages, or leave blank for all \(count).", value: ""),
                    ]
                )
            }
        }
        let pages = fields["pages"] ?? ""
        return writeOne(paths, command: "page-numbers", state: state) { url in
            saved([try PDFJobs.pageNumbers(url, startText: start, pagesText: pages)], kind: "PDFs")
        }
    }

    private static func compress(_ paths: [URL], fields: [String: String], state: URL) -> String {
        guard let quality = fields["quality"] else {
            return offerForm(paths, command: "compress", state: state) { url, _ in
                PDFJSON.form(
                    title: "Compress \(url.lastPathComponent)",
                    fields: [PDFJSON.textField(id: "quality", label: "Quality: low, medium, or high.", value: "medium")]
                )
            }
        }
        return writeOne(paths, command: "compress", state: state) { url in
            saved([try PDFJobs.compress(url, qualityText: quality)], kind: "PDFs")
        }
    }

    private static func pageCount(_ paths: [URL]) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        return catching(url) {
            let count = try PDFJobs.pageCount(url)
            let word = count == 1 ? "page" : "pages"
            return PDFJSON.ok("\(url.lastPathComponent) has \(count) \(word).")
        }
    }

    private static func info(_ paths: [URL]) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        return catching(url) {
            PDFJSON.ok(try PDFJobs.info(url))
        }
    }

    private static func extractText(_ paths: [URL]) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        return catching(url) {
            let text = try PDFJobs.extractText(url).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                return PDFJSON.ok("\(url.lastPathComponent) has no embedded text.")
            }
            return PDFJSON.note(title: "Text in \(url.lastPathComponent)", content: text)
        }
    }

    private static func jpegPDF(_ paths: [URL]) -> String {
        guard !paths.isEmpty else {
            return PDFJSON.fail(message(for: .needsImages, file: nil))
        }
        return catching(paths[0]) {
            PDFJSON.ok(saved([try PDFJobs.jpegPDF(paths)], kind: "PDFs"))
        }
    }

    private static func export(_ paths: [URL], format: PDFImageFormat, kind: String) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        return catching(url) {
            PDFJSON.ok(saved(try PDFJobs.export(url, format: format), kind: kind))
        }
    }

    private static func flatten(_ paths: [URL]) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        do {
            return PDFJSON.ok(saved([try PDFJobs.flatten(url)], kind: "PDFs"))
        } catch PDFToolError.noForms {
            return PDFJSON.ok(message(for: .noForms, file: url))
        } catch let error as PDFToolError {
            return PDFJSON.fail(message(for: error, file: url))
        } catch {
            return PDFJSON.fail(message(for: .unreadable, file: url))
        }
    }

    private static func grayscale(_ paths: [URL]) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        return catching(url) {
            PDFJSON.ok(saved([try PDFJobs.grayscale(url)], kind: "PDFs"))
        }
    }

    private static func bookmarks(
        _ paths: [URL],
        fields: [String: String],
        itemId: String?,
        state: URL
    ) -> String {
        if fields["title"] != nil {
            return saveBookmark(fields, state: state)
        }
        if let itemId {
            return bookmarkForm(itemId, state: state)
        }
        return offerForm(paths, command: "bookmarks", state: state) { url, _ in
            guard let document = try? PDFFiles.open(url) else {
                return PDFJSON.fail(message(for: .unreadable, file: url))
            }
            return PDFJSON.list(title: "Bookmarks in \(url.lastPathComponent)", items: PDFBookmarks.rows(in: document))
        }
    }

    private static func bookmarkForm(_ itemId: String, state: URL) -> String {
        guard var pending = PendingPDF.load(directory: state),
              pending.command == "bookmarks",
              pending.urls.count == 1,
              let url = pending.urls.first
        else {
            return PDFJSON.fail("Choose the PDF again.")
        }
        guard let document = try? PDFFiles.open(url) else {
            return PDFJSON.fail(message(for: .unreadable, file: url))
        }
        pending.bookmark = itemId
        guard (try? pending.save(directory: state)) != nil else {
            return PDFJSON.fail("Choose the PDF again.")
        }
        if itemId == "add" {
            return PDFJSON.form(
                title: "Add a bookmark to \(url.lastPathComponent)",
                fields: [
                    PDFJSON.textField(id: "title", label: "Title", value: ""),
                    PDFJSON.textField(id: "page", label: "Page", value: "1"),
                ]
            )
        }
        guard let node = PDFBookmarks.node(in: document, path: itemId) else {
            return PDFJSON.fail(message(for: .badBookmark, file: url))
        }
        let pageValue = node.pageIndex.map { String($0 + 1) } ?? ""
        return PDFJSON.form(
            title: "Edit bookmark in \(url.lastPathComponent)",
            fields: [
                PDFJSON.textField(id: "title", label: "Title", value: node.title),
                PDFJSON.textField(id: "page", label: "Page", value: pageValue),
            ]
        )
    }

    private static func saveBookmark(_ fields: [String: String], state: URL) -> String {
        guard let pending = PendingPDF.load(directory: state),
              pending.command == "bookmarks",
              let url = pending.urls.first
        else {
            return PDFJSON.fail("Choose the PDF again.")
        }
        let page = fields["page"] ?? ""
        if page.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PDFJSON.fail("Enter a page number.")
        }
        return catching(url) {
            let savedURL = try PDFBookmarks.save(
                url: url,
                target: pending.bookmark ?? "add",
                title: fields["title"] ?? "",
                pageText: page
            )
            PendingPDF.clear(directory: state)
            return PDFJSON.ok(saved([savedURL], kind: "PDFs"))
        }
    }

    private static func offerForm(
        _ paths: [URL],
        command: String,
        state: URL,
        reply: (URL, Int) -> String
    ) -> String {
        guard paths.count == 1, let url = paths.first else {
            return PDFJSON.fail(message(for: paths.isEmpty ? .unreadable : .needsOnePDF, file: nil))
        }
        do {
            let count = try PDFFiles.open(url).pageCount
            try PendingPDF(command: command, paths: [url.path], bookmark: nil).save(directory: state)
            return reply(url, count)
        } catch let error as PDFToolError {
            return PDFJSON.fail(message(for: error, file: url))
        } catch {
            return PDFJSON.fail(message(for: .unreadable, file: url))
        }
    }

    private static func writeOne(
        _ paths: [URL],
        command: String,
        state: URL,
        body: (URL) throws -> String
    ) -> String {
        let url: URL
        if let first = paths.first, paths.count == 1 {
            url = first
        } else if paths.isEmpty,
                  let pending = PendingPDF.load(directory: state),
                  pending.command == command,
                  let pendingURL = pending.urls.first,
                  pending.urls.count == 1 {
            url = pendingURL
        } else if paths.isEmpty {
            return PDFJSON.fail("Choose the PDF again.")
        } else {
            return PDFJSON.fail(message(for: .needsOnePDF, file: nil))
        }
        return catching(url) {
            let message = try body(url)
            PendingPDF.clear(directory: state)
            return PDFJSON.ok(message)
        }
    }

    private static func probe(_ url: URL) -> String? {
        do {
            _ = try PDFFiles.open(url)
            return nil
        } catch let error as PDFToolError {
            return PDFJSON.fail(message(for: error, file: url))
        } catch {
            return PDFJSON.fail(message(for: .unreadable, file: url))
        }
    }

    private static func catching(_ url: URL?, _ body: () throws -> String) -> String {
        do {
            return try body()
        } catch let error as PDFToolError {
            return PDFJSON.fail(message(for: error, file: url))
        } catch {
            return PDFJSON.fail(message(for: .unreadable, file: url))
        }
    }

    private static func saved(_ urls: [URL], kind: String) -> String {
        if urls.count == 1, let file = urls.first {
            return "Saved \(file.lastPathComponent) next to the original."
        }
        return "Saved \(urls.count) \(kind) next to the original."
    }

    private static func message(for error: PDFToolError, file: URL?) -> String {
        let name = file?.lastPathComponent
        switch error {
        case .unreadable:
            if let name { return "Couldn’t open \(name)." }
            return "Couldn’t open that file."
        case .locked:
            if let name { return "\(name) is locked. Remove the password first." }
            return "That PDF is locked. Remove the password first."
        case .writeFailed:
            if let name { return "Couldn’t save a copy of \(name)." }
            return "Couldn’t save the copy."
        case .badPages:
            return "Those page numbers don’t match this PDF."
        case .overlap:
            return "Those ranges overlap."
        case .badOrder:
            return "Enter every page once, like 3, 1, 2."
        case .badDegrees:
            return "Enter 90, 180, or 270."
        case .badQuality:
            return "Enter low, medium, or high."
        case .badStart:
            return "Enter the first page number."
        case .needsPages:
            return "Enter the pages, like 1, 3-5."
        case .needsTwoPDFs:
            return "Choose at least two PDFs."
        case .needsOnePDF:
            return "Choose one PDF."
        case .needsImages:
            return "Choose at least one JPEG."
        case .noForms:
            if let name { return "\(name) has no form fields." }
            return "This PDF has no form fields."
        case .notSmaller:
            if let name { return "Couldn’t make a smaller copy of \(name)." }
            return "Couldn’t make a smaller copy."
        case .badBookmark:
            return "That bookmark is no longer in this PDF."
        case .emptyTitle:
            return "Enter a bookmark title."
        }
    }
}
