import Foundation

public enum AtomicCommit {
    // existing live is moved aside to trashParent first, and restored from there if promote fails
    public static func promote(staging: URL, live: URL, trashParent: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: trashParent, withIntermediateDirectories: true)
        try fm.createDirectory(at: live.deletingLastPathComponent(), withIntermediateDirectories: true)

        var trashURL: URL?
        if fm.fileExists(atPath: live.path) {
            let name = "\(live.lastPathComponent)-\(UUID().uuidString)"
            let aside = trashParent.appendingPathComponent(name)
            try fm.moveItem(at: live, to: aside)
            trashURL = aside
        }

        do {
            try fm.moveItem(at: staging, to: live)
        } catch {
            if let trashURL, !fm.fileExists(atPath: live.path) {
                try? fm.moveItem(at: trashURL, to: live)
            }
            throw error
        }

        if let trashURL {
            try? fm.removeItem(at: trashURL)
        }
    }

    public static func recoverOrphans(stagingParent: URL, trashParent: URL) {
        let fm = FileManager.default
        for parent in [stagingParent, trashParent] {
            guard fm.fileExists(atPath: parent.path) else { continue }
            guard let children = try? fm.contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children {
                try? fm.removeItem(at: child)
            }
        }
    }
}
