import CryptoKit
import Foundation

public struct AppInstaller: Sendable {
    public var paths: JugnuPaths
    public var downloads: any InstallDownloading

    public init(paths: JugnuPaths, downloads: any InstallDownloading = AllowlistedDownloadSession()) {
        self.paths = paths
        self.downloads = downloads
    }

    public func stage(entry: AppRegistryEntry) async throws -> URL {
        guard let url = URL(string: entry.url) else {
            throw AppUpdateError.invalidRegistryURL
        }
        let zipURL = try await downloads.download(url)
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try requireSHA256(entry.sha256, of: zipURL)

        let staging = paths.appUpdateStagingDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try ZipExtractor.extract(zipURL: zipURL, to: staging)
            let app = try AppPackage.findAppBundle(in: staging)
            try AppPackage.check(bundle: app, expectedVersion: entry.version)
            return app
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    private func requireSHA256(_ expectedSHA256: String, of url: URL) throws {
        let expected = expectedSHA256.lowercased()
        guard !expected.isEmpty else { throw AddonInstallerError.sha256Required }
        let data = try Data(contentsOf: url)
        let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw AddonInstallerError.sha256Mismatch(expected: expected, actual: actual)
        }
    }
}
