import Foundation

enum PageList {
    static func indexes(in text: String, pageCount: Int) throws -> [Int] {
        try groups(in: text, pageCount: pageCount).flatMap { $0 }
    }

    static func groups(in text: String, pageCount: Int) throws -> [[Int]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw PDFToolError.needsPages
        }
        var groups: [[Int]] = []
        for raw in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            let part = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.isEmpty {
                throw PDFToolError.badPages
            }
            groups.append(try expand(part, pageCount: pageCount))
        }
        return groups
    }

    static func rejectingOverlap(_ groups: [[Int]]) throws -> [[Int]] {
        var seen = Set<Int>()
        for group in groups {
            for index in group where !seen.insert(index).inserted {
                throw PDFToolError.overlap
            }
        }
        return groups
    }

    static func permutation(_ text: String, pageCount: Int) throws -> [Int] {
        let indexes = try indexes(in: text, pageCount: pageCount)
        guard indexes.count == pageCount, Set(indexes).count == pageCount else {
            throw PDFToolError.badOrder
        }
        return indexes
    }

    static func degrees(_ text: String) throws -> Int {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "90":
            90
        case "180":
            180
        case "270":
            270
        default:
            throw PDFToolError.badDegrees
        }
    }

    static func startNumber(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Int(trimmed), number >= 0, number < 100_000 else {
            throw PDFToolError.badStart
        }
        return number
    }

    private static func expand(_ part: String, pageCount: Int) throws -> [Int] {
        let bits = part.split(separator: "-", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if bits.count == 1 {
            return [try one(bits[0], pageCount: pageCount)]
        }
        guard bits.count == 2 else {
            throw PDFToolError.badPages
        }
        let start = try one(bits[0], pageCount: pageCount)
        let end = try one(bits[1], pageCount: pageCount)
        guard start <= end else {
            throw PDFToolError.badPages
        }
        return Array(start ... end)
    }

    private static func one(_ text: String, pageCount: Int) throws -> Int {
        guard let number = Int(text), number >= 1, number <= pageCount else {
            throw PDFToolError.badPages
        }
        return number - 1
    }
}
