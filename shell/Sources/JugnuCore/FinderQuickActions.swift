import Foundation

public enum FinderMenu {
    public static let configKey = "show_in_finder_menu"

    public static func menuTitles(manifest: AddonManifest) -> [String] {
        manifest.commands.compactMap { command in
            guard let finder = command.finder else { return nil }
            return finder.menuTitle(commandTitle: command.title)
        }
    }

    public static func actions(
        manifest: AddonManifest,
        enabled: Bool,
        config: [String: JSONValue]
    ) -> [FinderQuickAction] {
        guard enabled, case let .bool(on) = config[configKey], on else { return [] }
        return manifest.commands.compactMap { command in
            guard let finder = command.finder else { return nil }
            return FinderQuickAction(
                addonID: manifest.id,
                commandID: command.id,
                menuTitle: finder.menuTitle(commandTitle: command.title),
                fileTypes: finder.fileTypes
            )
        }
    }
}

public struct FinderQuickAction: Equatable, Sendable {
    public var addonID: String
    public var commandID: String
    public var menuTitle: String
    public var fileTypes: [String]

    public init(addonID: String, commandID: String, menuTitle: String, fileTypes: [String]) {
        self.addonID = addonID
        self.commandID = commandID
        self.menuTitle = menuTitle
        self.fileTypes = fileTypes
    }
}

public func confirmFinderMenuUI(menuTitles: [String]) -> UIDescriptor {
    let message: String
    if menuTitles.count == 1, let title = menuTitles.first {
        message = "“\(title)” shows up when you right-click a matching file in Finder. You can change this later in Settings."
    } else {
        let lines = menuTitles.map { "• \($0)" }.joined(separator: "\n")
        message = "These show up when you right-click a matching file in Finder:\n\(lines)\nYou can change this later in Settings."
    }
    return UIDescriptor(
        pattern: .confirm,
        title: "Add to Finder’s right-click menu?",
        message: message,
        confirmLabel: "Add",
        cancelLabel: "Not now"
    )
}

public enum FinderQuickActions {
    public static let bundlePrefix = "app.jugnu.finder."

    public struct Request: Equatable, Sendable {
        public var addonID: String
        public var commandID: String
        public var id: String
    }

    public static func parse(_ url: URL) -> Request? {
        guard url.scheme == "jugnu", url.host == "finder" else { return nil }
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        var query: [String: String] = [:]
        for item in items {
            guard let value = item.value else { continue }
            query[item.name] = value
        }
        guard let addonID = query["addon"], let commandID = query["command"], let id = query["id"] else { return nil }
        guard isSafeToken(addonID), isSafeToken(commandID), isQueueID(id) else { return nil }
        return Request(addonID: addonID, commandID: commandID, id: id)
    }

    public static func queueFile(home: URL, addonID: String, commandID: String, id: String) -> URL? {
        guard isSafeToken(addonID), isSafeToken(commandID), isQueueID(id) else { return nil }
        return home
            .appendingPathComponent(".local/share/jugnu/finder-queue")
            .appendingPathComponent(addonID)
            .appendingPathComponent(commandID)
            .appendingPathComponent("\(id).txt")
    }

    public static func readQueue(at file: URL) -> [String] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        return data.split(separator: 0, omittingEmptySubsequences: true).compactMap { chunk in
            guard let path = String(data: Data(chunk), encoding: .utf8) else { return nil }
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    public static func sync(
        desired: [FinderQuickAction],
        servicesDirectory: URL,
        refreshServices: Bool
    ) throws {
        let fm = FileManager.default
        if desired.isEmpty, !fm.fileExists(atPath: servicesDirectory.path) {
            return
        }
        try fm.createDirectory(at: servicesDirectory, withIntermediateDirectories: true)
        var written: Set<String> = []
        for action in desired {
            let name = try workflowFilename(action)
            try write(action, to: servicesDirectory.appendingPathComponent(name))
            written.insert(name)
        }
        let existing = (try? fm.contentsOfDirectory(
            at: servicesDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        var removed = false
        for url in existing where url.pathExtension == "workflow" {
            guard isJugnuWorkflow(url), !written.contains(url.lastPathComponent) else { continue }
            try? fm.removeItem(at: url)
            removed = true
        }
        if refreshServices, !written.isEmpty || removed {
            refreshServicesMenu()
        }
    }

    public static func shellScript(addonID: String, commandID: String) -> String {
        """
        #!/bin/zsh
        id=$(uuidgen)
        dir="$HOME/.local/share/jugnu/finder-queue/\(addonID)/\(commandID)"
        mkdir -p "$dir"
        printf '%s\\0' "$@" > "$dir/$id.txt"
        open "jugnu://finder?addon=\(addonID)&command=\(commandID)&id=$id"
        """
    }

    static func workflowFilename(_ action: FinderQuickAction) throws -> String {
        guard isSafeToken(action.addonID), isSafeToken(action.commandID) else {
            throw FinderQuickActionError.unsafeID
        }
        return "\(action.addonID) \(action.commandID).workflow"
    }

    private static func write(_ action: FinderQuickAction, to workflow: URL) throws {
        guard isSafeToken(action.addonID), isSafeToken(action.commandID) else {
            throw FinderQuickActionError.unsafeID
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: workflow.path) {
            try fm.removeItem(at: workflow)
        }
        let contents = workflow.appendingPathComponent("Contents")
        try fm.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        let script = shellScript(addonID: action.addonID, commandID: action.commandID)
        let document = workflowDocument(script: script)
        let info = infoPlist(action)
        try writePlist(document, to: contents.appendingPathComponent("document.wflow"))
        try writePlist(document, to: contents.appendingPathComponent("Resources/document.wflow"))
        try writePlist(info, to: contents.appendingPathComponent("Info.plist"))
    }

    private static func workflowDocument(script: String) -> [String: Any] {
        let input = UUID().uuidString
        let output = UUID().uuidString
        let actionID = UUID().uuidString
        let action: [String: Any] = [
            "AMAccepts": [
                "Container": "List",
                "Optional": true,
                "Types": ["com.apple.cocoa.string"]
            ],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMProvides": [
                "Container": "List",
                "Types": ["com.apple.cocoa.string"]
            ],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": [
                "COMMAND_STRING": script,
                "CheckedForUserDefaultShell": true,
                "inputMethod": 1,
                "shell": "/bin/zsh",
                "source": ""
            ],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": input,
            "OutputUUID": output,
            "UUID": actionID,
            "isViewVisible": 1
        ]
        return [
            "AMApplicationBuild": "523",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": action, "isViewVisible": 1]],
            "connectors": [String: Any](),
            "workflowMetaData": [
                "serviceApplicationBundleID": "com.apple.finder",
                "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
                // Finder's service runner only understands Automator input types.
                // A file UTI here (com.adobe.pdf) makes it refuse to run. The menu
                // stays limited to those files via NSSendFileTypes.
                "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": 0,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu"
            ]
        ]
    }

    private static func infoPlist(_ action: FinderQuickAction) -> [String: Any] {
        [
            "CFBundleDevelopmentRegion": "en_US",
            "CFBundleIdentifier": "\(bundlePrefix)\(action.addonID).\(action.commandID)",
            "CFBundleName": action.menuTitle,
            "CFBundleShortVersionString": "1.0",
            "NSServices": [[
                "NSMenuItem": ["default": action.menuTitle],
                "NSMessage": "runWorkflowAsService",
                "NSRequiredContext": ["NSApplicationIdentifier": "com.apple.finder"],
                "NSSendFileTypes": action.fileTypes
            ]]
        ]
    }

    private static func writePlist(_ object: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private static func isJugnuWorkflow(_ url: URL) -> Bool {
        let info = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: info),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String
        else { return false }
        return identifier.hasPrefix(bundlePrefix)
    }

    private static func refreshServicesMenu() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        process.arguments = ["-update"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func isSafeToken(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil
    }

    private static func isQueueID(_ value: String) -> Bool {
        value.range(
            of: "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$",
            options: .regularExpression
        ) != nil
    }
}

public enum FinderQuickActionError: Error, Equatable {
    case unsafeID
}
