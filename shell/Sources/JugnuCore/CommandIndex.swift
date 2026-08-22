import Foundation

public struct IndexedCommand: Equatable, Sendable {
    public var addonId: String
    public var commandId: String
    public var title: String
    public var subtitle: String
    public var keywords: [String]
    public var addonRoot: URL
    public var defaultUIPattern: UIPattern?

    public init(
        addonId: String,
        commandId: String,
        title: String,
        subtitle: String,
        keywords: [String],
        addonRoot: URL,
        defaultUIPattern: UIPattern? = nil
    ) {
        self.addonId = addonId
        self.commandId = commandId
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.addonRoot = addonRoot
        self.defaultUIPattern = defaultUIPattern
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
                        defaultUIPattern: cmd.defaultUIPattern
                    )
                )
            }
        }

        commands = found.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func search(_ query: String) -> [IndexedCommand] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return all }
        let needle = q.lowercased()
        return all.filter { cmd in
            if cmd.title.lowercased().contains(needle) { return true }
            if cmd.subtitle.lowercased().contains(needle) { return true }
            if cmd.qualifiedId.lowercased().contains(needle) { return true }
            return cmd.keywords.contains { $0.lowercased().contains(needle) }
        }
    }
}
