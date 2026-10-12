import Foundation
import PDFKit

public enum PDFUnlockError: Error, Equatable {
    case unreadable
    case notProtected
    case needsPassword
    case wrongPassword
    case writeFailed
}

public enum PDFUnlock {
    public static func destination(beside source: URL, fileManager: FileManager = .default) -> URL {
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.isEmpty ? "pdf" : source.pathExtension
        var index = 1
        while true {
            let name = index == 1 ? "\(stem) (unlocked).\(ext)" : "\(stem) (unlocked) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    public static func removePassword(from source: URL, password: String?) throws -> URL {
        guard let document = PDFDocument(url: source) else {
            throw PDFUnlockError.unreadable
        }
        if document.isLocked {
            let trimmed = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                throw PDFUnlockError.needsPassword
            }
            guard document.unlock(withPassword: trimmed) else {
                throw PDFUnlockError.wrongPassword
            }
        } else if !document.isEncrypted {
            throw PDFUnlockError.notProtected
        }

        let pages = (0 ..< document.pageCount).compactMap { document.page(at: $0) }
        let copy = PDFDocument()
        for page in pages {
            copy.insert(page, at: copy.pageCount)
        }
        guard copy.pageCount == pages.count, copy.pageCount > 0 else {
            throw PDFUnlockError.unreadable
        }
        let output = destination(beside: source)
        guard copy.write(to: output) else {
            throw PDFUnlockError.writeFailed
        }
        guard let written = PDFDocument(url: output), !written.isLocked, !written.isEncrypted else {
            try? FileManager.default.removeItem(at: output)
            throw PDFUnlockError.writeFailed
        }
        return output
    }
}

public enum PendingUnlock {
    public static func file(in directory: URL) -> URL {
        directory.appendingPathComponent("pending-unlock")
    }

    public static func save(_ urls: [URL], directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = urls.map(\.path).joined(separator: "\0")
        try Data(payload.utf8).write(to: file(in: directory), options: .atomic)
    }

    public static func load(directory: URL) -> [URL] {
        guard let data = try? Data(contentsOf: file(in: directory)) else { return [] }
        return data.split(separator: 0, omittingEmptySubsequences: true).compactMap { chunk in
            guard let path = String(data: Data(chunk), encoding: .utf8), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        }
    }

    public static func clear(directory: URL) {
        try? FileManager.default.removeItem(at: file(in: directory))
    }
}

public struct PDFUnlockBatch: Equatable {
    public var saved: [URL]
    public var unprotected: [String]
    public var ask: URL?
    public var wrongPassword: Bool
    public var failure: String?

    public init(
        saved: [URL],
        unprotected: [String],
        ask: URL?,
        wrongPassword: Bool,
        failure: String?
    ) {
        self.saved = saved
        self.unprotected = unprotected
        self.ask = ask
        self.wrongPassword = wrongPassword
        self.failure = failure
    }
}

public enum PDFUnlockSession {
    public static func run(files: [URL], password: String?, stateDirectory: URL) -> PDFUnlockBatch {
        if password == nil {
            PendingUnlock.clear(directory: stateDirectory)
        }
        var saved: [URL] = []
        var unprotected: [String] = []
        for (index, file) in files.enumerated() {
            let attempt = index == 0 ? password : nil
            do {
                saved.append(try PDFUnlock.removePassword(from: file, password: attempt))
            } catch PDFUnlockError.notProtected {
                unprotected.append(file.lastPathComponent)
            } catch PDFUnlockError.needsPassword {
                try? PendingUnlock.save(Array(files[index...]), directory: stateDirectory)
                return PDFUnlockBatch(
                    saved: saved,
                    unprotected: unprotected,
                    ask: file,
                    wrongPassword: false,
                    failure: nil
                )
            } catch PDFUnlockError.wrongPassword {
                try? PendingUnlock.save(Array(files[index...]), directory: stateDirectory)
                return PDFUnlockBatch(
                    saved: saved,
                    unprotected: unprotected,
                    ask: file,
                    wrongPassword: true,
                    failure: nil
                )
            } catch let error as PDFUnlockError {
                return PDFUnlockBatch(
                    saved: saved,
                    unprotected: unprotected,
                    ask: nil,
                    wrongPassword: false,
                    failure: message(for: error, file: file)
                )
            } catch {
                return PDFUnlockBatch(
                    saved: saved,
                    unprotected: unprotected,
                    ask: nil,
                    wrongPassword: false,
                    failure: "Couldn’t open \(file.lastPathComponent)."
                )
            }
        }
        PendingUnlock.clear(directory: stateDirectory)
        return PDFUnlockBatch(
            saved: saved,
            unprotected: unprotected,
            ask: nil,
            wrongPassword: false,
            failure: nil
        )
    }

    private static func message(for error: PDFUnlockError, file: URL) -> String {
        switch error {
        case .writeFailed:
            "Couldn’t save the unlocked copy of \(file.lastPathComponent)."
        case .unreadable, .notProtected, .needsPassword, .wrongPassword:
            "Couldn’t open \(file.lastPathComponent)."
        }
    }
}

public enum PDFUnlockReply {
    public static func json(for batch: PDFUnlockBatch) -> String {
        if batch.wrongPassword, let file = batch.ask {
            return encode(ok: false, error: "That password didn’t open \(file.lastPathComponent).")
        }
        if let failure = batch.failure {
            return encode(ok: false, error: failure)
        }
        if let file = batch.ask {
            return encode(
                ok: true,
                ui: form(
                    message: askMessage(file: file, saved: batch.saved, unprotected: batch.unprotected),
                    title: "Password for \(file.lastPathComponent)"
                )
            )
        }
        return encode(ok: true, message: summary(saved: batch.saved, unprotected: batch.unprotected))
    }

    public static func summary(saved: [URL], unprotected: [String]) -> String {
        var parts: [String] = []
        if saved.count == 1, let file = saved.first {
            parts.append("Saved \(file.lastPathComponent) next to the original.")
        } else if saved.count > 1 {
            parts.append("Saved \(saved.count) unlocked PDFs next to the originals.")
        }
        if unprotected.count == 1, let name = unprotected.first {
            parts.append("\(name) doesn’t have a password.")
        } else if unprotected.count > 1 {
            parts.append("\(unprotected.count) PDFs don’t have a password.")
        }
        return parts.isEmpty ? "No PDF selected." : parts.joined(separator: " ")
    }

    public static func askMessage(file: URL, saved: [URL], unprotected: [String]) -> String {
        var lead = summary(saved: saved, unprotected: unprotected)
        if lead == "No PDF selected." {
            lead = ""
        } else {
            lead += " "
        }
        return lead + "Enter the password for \(file.lastPathComponent). An unlocked copy is saved beside it."
    }

    private static func form(message: String, title: String) -> [String: Any] {
        [
            "fields": [[
                "id": "password",
                "kind": "password",
                "label": "Password",
            ]],
            "message": message,
            "pattern": "form",
            "title": title,
            "view": "fields",
        ]
    }

    private static func encode(ok: Bool, message: String? = nil, error: String? = nil, ui: [String: Any]? = nil) -> String {
        var object: [String: Any] = ["ok": ok]
        if let message {
            object["message"] = message
        }
        if let error {
            object["error"] = error
        }
        if let ui {
            object["ui"] = ui
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"Couldn’t build a reply.\",\"ok\":false}"
        }
        return json
    }
}
