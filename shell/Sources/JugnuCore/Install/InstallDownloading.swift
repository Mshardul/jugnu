import Foundation

public protocol InstallDownloading: Sendable {
    /// Downloads `url` to a temporary file. Caller owns cleanup.
    func download(_ url: URL) async throws -> URL
}

extension AllowlistedDownloadSession: InstallDownloading {}
