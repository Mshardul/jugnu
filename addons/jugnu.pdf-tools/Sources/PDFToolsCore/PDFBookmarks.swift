import CoreGraphics
import Foundation
import PDFKit

struct OutlineNode {
    var title: String
    var pageIndex: Int?
    var children: [OutlineNode]
}

enum PDFBookmarks {
    static func rows(in document: PDFDocument) -> [[String: String]] {
        var items = [[
            "id": "add",
            "subtitle": "Save a copy with a new bookmark",
            "title": "Add bookmark",
        ]]
        for row in flatten(capture(document), prefix: "") {
            let depth = row.path.split(separator: ".").count - 1
            let name = row.node.title.isEmpty ? "Bookmark" : row.node.title
            let page = row.node.pageIndex.map { "Page \($0 + 1)" } ?? "No page"
            items.append([
                "id": row.path,
                "subtitle": page,
                "title": String(repeating: "– ", count: depth) + name,
            ])
        }
        return items
    }

    static func save(url: URL, target: String, title: String, pageText: String) throws -> URL {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PDFToolError.emptyTitle
        }
        let document = try PDFFiles.open(url)
        let indexes = try PageList.indexes(in: pageText, pageCount: document.pageCount)
        guard indexes.count == 1, let pageIndex = indexes.first else {
            throw PDFToolError.badPages
        }
        var nodes = capture(document)
        if target == "add" {
            nodes.append(OutlineNode(title: trimmed, pageIndex: pageIndex, children: []))
        } else {
            guard update(&nodes, path: try parse(target), title: trimmed, pageIndex: pageIndex) else {
                throw PDFToolError.badBookmark
            }
        }
        let copy = try PDFFiles.copyPages(document, indexes: Array(0 ..< document.pageCount))
        apply(nodes, to: copy)
        let stem = url.deletingPathExtension().lastPathComponent
        return try PDFFiles.write(copy, beside: url, label: "\(stem) (bookmarks)")
    }

    static func node(in document: PDFDocument, path: String) -> OutlineNode? {
        guard let indexes = try? parse(path) else {
            return nil
        }
        return walk(capture(document), path: indexes)
    }

    private static func capture(_ document: PDFDocument) -> [OutlineNode] {
        guard let root = document.outlineRoot else {
            return []
        }
        return children(of: root, in: document)
    }

    private static func children(of outline: PDFOutline, in document: PDFDocument) -> [OutlineNode] {
        (0 ..< outline.numberOfChildren).compactMap { index in
            guard let child = outline.child(at: index) else {
                return nil
            }
            return node(child, in: document)
        }
    }

    private static func node(_ outline: PDFOutline, in document: PDFDocument) -> OutlineNode {
        var pageIndex: Int?
        if let page = outline.destination?.page {
            let index = document.index(for: page)
            if index != NSNotFound {
                pageIndex = index
            }
        }
        return OutlineNode(
            title: outline.label ?? "",
            pageIndex: pageIndex,
            children: children(of: outline, in: document)
        )
    }

    private static func flatten(_ nodes: [OutlineNode], prefix: String) -> [(path: String, node: OutlineNode)] {
        var rows: [(String, OutlineNode)] = []
        for (index, node) in nodes.enumerated() {
            let path = prefix.isEmpty ? "\(index)" : "\(prefix).\(index)"
            rows.append((path, node))
            rows.append(contentsOf: flatten(node.children, prefix: path))
        }
        return rows
    }

    private static func parse(_ path: String) throws -> [Int] {
        let parts = path.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            throw PDFToolError.badBookmark
        }
        return try parts.map { part in
            guard let number = Int(part), number >= 0, String(number) == part else {
                throw PDFToolError.badBookmark
            }
            return number
        }
    }

    private static func walk(_ nodes: [OutlineNode], path: [Int]) -> OutlineNode? {
        guard let first = path.first, nodes.indices.contains(first) else {
            return nil
        }
        if path.count == 1 {
            return nodes[first]
        }
        return walk(nodes[first].children, path: Array(path.dropFirst()))
    }

    private static func update(
        _ nodes: inout [OutlineNode],
        path: [Int],
        title: String,
        pageIndex: Int
    ) -> Bool {
        guard let first = path.first, nodes.indices.contains(first) else {
            return false
        }
        if path.count == 1 {
            nodes[first].title = title
            nodes[first].pageIndex = pageIndex
            return true
        }
        return update(&nodes[first].children, path: Array(path.dropFirst()), title: title, pageIndex: pageIndex)
    }

    private static func apply(_ nodes: [OutlineNode], to document: PDFDocument) {
        let root = PDFOutline()
        for node in nodes {
            root.insertChild(outline(node, in: document), at: root.numberOfChildren)
        }
        document.outlineRoot = root
    }

    private static func outline(_ node: OutlineNode, in document: PDFDocument) -> PDFOutline {
        let outline = PDFOutline()
        outline.label = node.title
        if let pageIndex = node.pageIndex, let page = document.page(at: pageIndex) {
            let bounds = page.bounds(for: .mediaBox)
            outline.destination = PDFDestination(page: page, at: CGPoint(x: bounds.minX, y: bounds.maxY))
        }
        for child in node.children {
            outline.insertChild(self.outline(child, in: document), at: outline.numberOfChildren)
        }
        return outline
    }
}
