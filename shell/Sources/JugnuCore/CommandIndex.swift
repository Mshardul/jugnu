import Foundation

public struct IndexedCommand: Equatable, Sendable {
    public var addonId: String
    public var commandId: String
    public var title: String
    public var subtitle: String
    public var keywords: [String]
    public var addonRoot: URL
    public var defaultUIPattern: UIPattern?
    public var defaultViewType: ViewType?
    public var allowedViewTypes: [ViewType]

    public init(
        addonId: String,
        commandId: String,
        title: String,
        subtitle: String,
        keywords: [String],
        addonRoot: URL,
        defaultUIPattern: UIPattern? = nil,
        defaultViewType: ViewType? = nil,
        allowedViewTypes: [ViewType] = ViewType.shellDefaults
    ) {
        self.addonId = addonId
        self.commandId = commandId
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.addonRoot = addonRoot
        self.defaultUIPattern = defaultUIPattern
        self.defaultViewType = defaultViewType
        self.allowedViewTypes = allowedViewTypes
    }

    public var qualifiedId: String { "\(addonId).\(commandId)" }
}

public struct CommandIndex: Sendable {
    public let paths: JugnuPaths
    public var config: JugnuConfig
    public var extraAddonRoots: [URL]
    private var commands: [IndexedCommand] = []

    public var all: [IndexedCommand] { commands }

    public init(paths: JugnuPaths, config: JugnuConfig, extraAddonRoots: [URL] = []) {
        self.paths = paths
        self.config = config
        self.extraAddonRoots = extraAddonRoots
    }

    public mutating func rebuild() throws {
        var found: [IndexedCommand] = []
        var rootsById: [String: URL] = [:]

        let fm = FileManager.default
        if fm.fileExists(atPath: paths.addonsDir.path),
           let children = try? fm.contentsOfDirectory(
               at: paths.addonsDir,
               includingPropertiesForKeys: [.isDirectoryKey],
               options: [.skipsHiddenFiles]
           ) {
            for child in children {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue else { continue }
                rootsById[child.lastPathComponent] = child
            }
        }

        for root in extraAddonRoots {
            let manifest: AddonManifest
            do {
                manifest = try ManifestLoader.load(from: root)
            } catch {
                continue
            }
            rootsById[manifest.id] = root
        }

        for (id, root) in rootsById {
            guard config.addons[id]?.enabled == true else { continue }
            let manifest = try ManifestLoader.load(from: root)
            for cmd in manifest.commands {
                found.append(
                    IndexedCommand(
                        addonId: manifest.id,
                        commandId: cmd.id,
                        title: cmd.title,
                        subtitle: cmd.subtitle,
                        keywords: cmd.keywords,
                        addonRoot: root,
                        defaultUIPattern: cmd.defaultUIPattern,
                        defaultViewType: cmd.view,
                        allowedViewTypes: manifest.allowedViewTypes
                    )
                )
            }
        }

        commands = found.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public mutating func replaceCommandsForTesting(_ commands: [IndexedCommand]) {
        self.commands = commands
    }

    public func search(_ query: String) -> [IndexedCommand] {
        searchHits(query).map(\.command)
    }

    public func searchHits(_ query: String) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return all.map { SearchHit(command: $0, tier: .title, score: 0, isSuggestion: false) }
        }

        var hits: [SearchHit] = []
        for command in commands {
            if let ranked = rank(command, query: trimmed) {
                hits.append(ranked)
            }
        }
        hits.sort { lhs, rhs in
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.command.title.localizedCaseInsensitiveCompare(rhs.command.title) == .orderedAscending
        }
        if hits.isEmpty, let suggestion = closest(query: trimmed) {
            return [suggestion]
        }
        return hits
    }

    private func rank(_ command: IndexedCommand, query: String) -> SearchHit? {
        let titleScore = Fuzzy.score(query: query, in: command.title)
        if titleScore > 0 {
            return SearchHit(command: command, tier: .title, score: titleScore, isSuggestion: false)
        }
        let keywordScore = command.keywords.map { Fuzzy.score(query: query, in: $0) }.max() ?? 0
        if keywordScore > 0 {
            return SearchHit(command: command, tier: .keyword, score: keywordScore, isSuggestion: false)
        }
        let subtitleScore = Fuzzy.score(query: query, in: command.subtitle)
        if subtitleScore > 0 {
            return SearchHit(command: command, tier: .subtitle, score: subtitleScore, isSuggestion: false)
        }
        return nil
    }

    private func closest(query: String) -> SearchHit? {
        var best: SearchHit?
        var bestDistance = Int.max
        for command in commands {
            let titleScore = Fuzzy.score(query: query, in: command.title)
            let keywordScore = command.keywords.map { Fuzzy.score(query: query, in: $0) }.max() ?? 0
            let subtitleScore = Fuzzy.score(query: query, in: command.subtitle)
            let score = max(titleScore, keywordScore, subtitleScore)
            let distance = Fuzzy.editDistance(Fuzzy.fold(query), Fuzzy.fold(command.title))
            let candidate = SearchHit(command: command, tier: .title, score: score, isSuggestion: true)
            let betterScore = score > (best?.score ?? -1)
            let sameScoreCloser = score == (best?.score ?? -1) && distance < bestDistance
            let sameScoreSameDistAlpha = score == (best?.score ?? -1)
                && distance == bestDistance
                && command.title.localizedCaseInsensitiveCompare(best?.command.title ?? command.title)
                == .orderedAscending
            if best == nil || betterScore || sameScoreCloser || sameScoreSameDistAlpha {
                best = candidate
                bestDistance = distance
            }
        }
        return best
    }
}
