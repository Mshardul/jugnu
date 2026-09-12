import Foundation

public protocol InstallDownloading: Sendable {
    /// caller owns cleanup of the returned temp file
    func download(_ url: URL) async throws -> URL
}

extension AllowlistedDownloadSession: InstallDownloading {}
