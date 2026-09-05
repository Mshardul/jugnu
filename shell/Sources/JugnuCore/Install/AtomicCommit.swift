import Foundation

public enum AtomicCommit {
    /// Promote `staging` to `live`. If `live` exists, move it aside under `trashParent` first.
    /// On failure after live was moved aside, attempts to restore it from trash.
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

    /// Delete orphaned staging trees and empty-able trash under the given parents.
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
