import CryptoKit
import Foundation

public struct AddonInstaller: Sendable {
    public let paths: JugnuPaths
    public let store: ConfigStore

    public init(paths: JugnuPaths, store: ConfigStore? = nil) {
        self.paths = paths
        self.store = store ?? ConfigStore(paths: paths)
    }

    public func install(entry: RegistryEntry, enable: Bool) async throws {
        guard let remote = URL(string: entry.url), !entry.url.isEmpty else {
            throw AddonInstallerError.missingURL
        }
        let (tempURL, _) = try await URLSession.shared.download(from: remote)
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(entry.id)-\(UUID().uuidString).zip")
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.moveItem(at: tempURL, to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try installFromLocalZip(url: zipURL, expectedSHA256: entry.sha256, enable: enable, addonId: entry.id)
    }

    public func installFromLocalZip(
        url: URL,
        expectedSHA256: String?,
        enable: Bool,
        addonId: String? = nil
    ) throws {
        let data = try Data(contentsOf: url)
        if let expected = expectedSHA256?.lowercased(), !expected.isEmpty {
            let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            guard actual == expected else {
                throw AddonInstallerError.sha256Mismatch(expected: expected, actual: actual)
            }
        }

        let extractRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractRoot) }

        try unzip(zipURL: url, to: extractRoot)

        let packageRoot = try findAddonRoot(in: extractRoot)
        let manifest = try ManifestLoader.load(from: packageRoot)
        let id = addonId ?? manifest.id
        guard id == manifest.id else {
            throw AddonInstallerError.idMismatch(expected: id, actual: manifest.id)
        }

        try FileManager.default.createDirectory(at: paths.addonsDir, withIntermediateDirectories: true)
        let dest = paths.addonsDir.appendingPathComponent(id)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: packageRoot, to: dest)

        var config = try store.loadOrCreateDefaults()
        config.addons[id] = AddonConfig(enabled: enable)
        try store.save(config)
    }

    /// Install an already-unpacked addon directory (dev / first-run local path).
    public func installFromDirectory(url: URL, enable: Bool) throws {
        let manifest = try ManifestLoader.load(from: url)
        try FileManager.default.createDirectory(at: paths.addonsDir, withIntermediateDirectories: true)
        let dest = paths.addonsDir.appendingPathComponent(manifest.id)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        var config = try store.loadOrCreateDefaults()
        config.addons[manifest.id] = AddonConfig(enabled: enable)
        try store.save(config)
    }

    private func findAddonRoot(in extractRoot: URL) throws -> URL {
        let fm = FileManager.default
        let direct = extractRoot.appendingPathComponent("addon.yaml")
        if fm.fileExists(atPath: direct.path) { return extractRoot }

        let children = try fm.contentsOfDirectory(
            at: extractRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for child in children {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if fm.fileExists(atPath: child.appendingPathComponent("addon.yaml").path) {
                return child
            }
        }
        throw AddonInstallerError.addonYAMLMissing
    }

    private func unzip(zipURL: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", destination.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AddonInstallerError.unzipFailed
        }
    }
}

public enum AddonInstallerError: Error, Equatable {
    case missingURL
    case sha256Mismatch(expected: String, actual: String)
    case idMismatch(expected: String, actual: String)
    case addonYAMLMissing
    case unzipFailed
}
