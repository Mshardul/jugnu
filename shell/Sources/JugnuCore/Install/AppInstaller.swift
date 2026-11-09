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
        try SHA256Digest.requireWellFormed(entry.sha256)
        let zipURL = try await downloads.download(url)
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try SHA256Digest.verify(entry.sha256, file: zipURL)

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
}
