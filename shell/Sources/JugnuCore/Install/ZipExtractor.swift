import Foundation
import ZIPFoundation

public enum ZipExtractor {
    public static let defaultMaxEntries = 50_000
    public static let defaultMaxUncompressedBytes: UInt64 = 512_000_000

    public static func extract(
        zipURL: URL,
        to destination: URL,
        maxEntries: Int = defaultMaxEntries,
        maxUncompressedBytes: UInt64 = defaultMaxUncompressedBytes
    ) throws {
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw AddonInstallerError.unsafeArchive
        }

        var entryCount = 0
        var totalUncompressed: UInt64 = 0
        let destRoot = destination.standardizedFileURL

        for entry in archive {
            entryCount += 1
            if entryCount > maxEntries {
                throw AddonInstallerError.archiveTooLarge
            }

            try validateEntryPath(entry.path, destination: destRoot)

            if entry.type == .symlink {
                throw AddonInstallerError.unsafeArchive
            }

            totalUncompressed += entry.uncompressedSize
            if totalUncompressed > maxUncompressedBytes {
                throw AddonInstallerError.archiveTooLarge
            }

            let entryURL = destRoot.appendingPathComponent(entry.path)
            _ = try archive.extract(entry, to: entryURL, allowUncontainedSymlinks: false)
        }
    }

    public static func findPackageRoot(in extractRoot: URL, manifestName: String) throws -> URL {
        let fm = FileManager.default
        let direct = extractRoot.appendingPathComponent(manifestName)
        if fm.fileExists(atPath: direct.path) {
            return extractRoot
        }

        let children = try fm.contentsOfDirectory(
            at: extractRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var matches: [URL] = []
        for child in children {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if fm.fileExists(atPath: child.appendingPathComponent(manifestName).path) {
                matches.append(child)
            }
        }
        guard matches.count == 1, let only = matches.first else {
            if manifestName == "addon.yaml" {
                throw AddonInstallerError.addonYAMLMissing
            }
            throw AddonInstallerError.helperYAMLMissing
        }
        return only
    }

    static func validateEntryPath(_ entryPath: String, destination: URL) throws {
        if entryPath.hasPrefix("/") || entryPath.hasPrefix("\\") {
            throw AddonInstallerError.unsafeArchive
        }
        let normalized = entryPath.replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.contains("..") {
            throw AddonInstallerError.unsafeArchive
        }
        let destPath = destination.path
        let proposed = destination.appendingPathComponent(normalized).standardizedFileURL.path
        let prefix = destPath.hasSuffix("/") ? destPath : destPath + "/"
        if proposed != destPath && !proposed.hasPrefix(prefix) {
            throw AddonInstallerError.unsafeArchive
        }
    }
}
