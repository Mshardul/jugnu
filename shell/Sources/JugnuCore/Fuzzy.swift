import Foundation

public enum SearchTier: Int, Comparable, Sendable {
    case title = 0
    case keyword = 1
    case subtitle = 2

    public static func < (lhs: SearchTier, rhs: SearchTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SearchHit: Equatable, Sendable {
    public var command: IndexedCommand
    public var tier: SearchTier
    public var score: Int
    public var isSuggestion: Bool

    public init(command: IndexedCommand, tier: SearchTier, score: Int, isSuggestion: Bool) {
        self.command = command
        self.tier = tier
        self.score = score
        self.isSuggestion = isSuggestion
    }
}

public enum Fuzzy {
    public static func score(query: String, in text: String) -> Int {
        let needle = tokens(query)
        guard !needle.isEmpty else { return 0 }
        let hay = tokens(text)
        var qi = 0
        var score = 0
        var lastHayIndex: Int?
        for (hi, token) in hay.enumerated() {
            guard qi < needle.count else { break }
            guard token.char == needle[qi].char else { continue }
            let consecutive = lastHayIndex.map { hi == $0 + 1 } ?? false
            if token.boundary {
                score += 8
            } else if consecutive {
                score += 4
            } else {
                score += 1
            }
            lastHayIndex = hi
            qi += 1
        }
        return qi == needle.count ? score : 0
    }

    public static func editDistance(_ a: String, _ b: String) -> Int {
        let left = Array(fold(a))
        let right = Array(fold(b))
        if left.isEmpty {
            return right.count
        }
        if right.isEmpty {
            return left.count
        }
        var prev = Array(0 ... right.count)
        var current = Array(repeating: 0, count: right.count + 1)
        for i in 1 ... left.count {
            current[0] = i
            for j in 1 ... right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = min(
                    prev[j] + 1,
                    current[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            prev = current
        }
        return prev[right.count]
    }

    public static func fold(_ value: String) -> String {
        String(tokens(value).map(\.char))
    }

    private struct Token {
        var char: Character
        var boundary: Bool
    }

    private static func tokens(_ value: String) -> [Token] {
        var result: [Token] = []
        var prevAlnum = false
        for scalar in value.lowercased().unicodeScalars {
            let isAlnum = CharacterSet.alphanumerics.contains(scalar)
            if isAlnum {
                result.append(Token(char: Character(scalar), boundary: !prevAlnum))
                prevAlnum = true
            } else {
                prevAlnum = false
            }
        }
        return result
    }
}
