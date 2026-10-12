import AppKit
import Foundation
import PDFToolsCore
import UniformTypeIdentifiers

enum Arg: Decodable {
    case string(String)
    case array([String])
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([String].self) {
            self = .array(value)
            return
        }
        self = .other
    }
}

struct RunRequestJSON: Decodable {
    var command: String
    var args: [String: Arg]?
}

enum PDFToolsMain {
    static func run() throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let request: RunRequestJSON
        if data.isEmpty {
            request = RunRequestJSON(command: "pdf-unlock", args: nil)
        } else {
            request = try JSONDecoder().decode(RunRequestJSON.self, from: data)
        }
        let args = request.args ?? [:]
        if request.command != "pdf-unlock" {
            runFileCommand(request.command, args: args)
            return
        }
        let password = args["password"].flatMap { value -> String? in
            if case let .string(text) = value { return text }
            return nil
        }
        if let password, password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reply("{\"error\":\"Enter the PDF password.\",\"ok\":false}")
            return
        }
        var files = paths(from: args["paths"])
        if files.isEmpty, case let .string(path) = args["path"] {
            files = [URL(fileURLWithPath: path)]
        }
        let state = stateDirectory()
        if files.isEmpty {
            if password != nil {
                files = PendingUnlock.load(directory: state)
                if files.isEmpty {
                    reply("{\"error\":\"Choose the PDF again.\",\"ok\":false}")
                    return
                }
            } else {
                files = pickPDFs()
                if files.isEmpty {
                    reply("{\"message\":\"No PDF selected.\",\"ok\":true}")
                    return
                }
            }
        }
        let batch = PDFUnlockSession.run(files: files, password: password, stateDirectory: state)
        reply(PDFUnlockReply.json(for: batch))
    }

    private static let fileCommands: Set<String> = [
        "bookmarks", "compress", "extract-pages", "extract-text", "flatten-forms", "grayscale",
        "info", "jpg-pdf", "merge", "organize", "page-count", "page-numbers", "pdf-jpg", "pdf-png",
        "rotate", "split",
    ]

    private static func runFileCommand(_ command: String, args: [String: Arg]) {
        guard fileCommands.contains(command) else {
            reply("{\"error\":\"Unknown command.\",\"ok\":false}")
            return
        }
        var fields: [String: String] = [:]
        for (key, value) in args {
            if key == "path" {
                continue
            }
            if case let .string(text) = value {
                fields[key] = text
            }
        }
        let itemId = fields.removeValue(forKey: "itemId")
        var files = paths(from: args["paths"])
        if files.isEmpty, case let .string(path) = args["path"] {
            files = [URL(fileURLWithPath: path)]
        }
        if files.isEmpty, !PDFToolsSession.isFollowUp(command: command, fields: fields, itemId: itemId) {
            files = pick(command: command)
            if files.isEmpty {
                let message = command == "jpg-pdf" ? "No JPEG selected." : "No PDF selected."
                reply("{\"message\":\"\(message)\",\"ok\":true}")
                return
            }
        }
        reply(PDFToolsSession.run(
            command: command,
            fields: fields,
            paths: files,
            itemId: itemId,
            stateDirectory: stateDirectory()
        ))
    }

    private static func paths(from arg: Arg?) -> [URL] {
        guard case let .array(values) = arg else { return [] }
        return values.map { URL(fileURLWithPath: $0) }
    }

    private static func stateDirectory() -> URL {
        if let raw = ProcessInfo.processInfo.environment["JUGNU_STATE_DIR"], !raw.isEmpty {
            return URL(fileURLWithPath: raw)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/jugnu/state/pdf-tools")
    }

    private static func pickPDFs() -> [URL] {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Unlock"
        panel.message = "Choose the PDFs to unlock."
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    private static func pick(command: String) -> [URL] {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if command == "jpg-pdf" {
            panel.allowedContentTypes = [.jpeg]
            panel.allowsMultipleSelection = true
            panel.prompt = "Create PDF"
            panel.message = "Choose JPEG images, in the order you want the pages."
        } else if command == "merge" {
            panel.allowedContentTypes = [.pdf]
            panel.allowsMultipleSelection = true
            panel.prompt = "Merge"
            panel.message = "Choose two or more PDFs, in the order you want the pages."
        } else {
            panel.allowedContentTypes = [.pdf]
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            panel.message = "Choose a PDF."
        }
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    private static func reply(_ json: String) {
        FileHandle.standardOutput.write(Data(json.utf8))
    }
}

do {
    try PDFToolsMain.run()
} catch {
    FileHandle.standardOutput.write(Data("{\"error\":\"Couldn’t read that request.\",\"ok\":false}".utf8))
}
