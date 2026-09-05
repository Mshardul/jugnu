import Foundation

/// Downloads over HTTPS with redirect hops confined to `InstallHostAllowlist`.
public final class AllowlistedDownloadSession: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private var session: URLSession!

    public override init() {
        super.init()
        let config = URLSessionConfiguration.ephemeral
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Downloads `url` to a temporary file. Caller owns cleanup of the returned URL.
    public func download(_ url: URL) async throws -> URL {
        guard InstallHostAllowlist.isAllowed(url) else {
            throw AddonInstallerError.hostNotAllowed
        }
        do {
            let (tempURL, _) = try await session.download(from: url)
            return tempURL
        } catch let error as AddonInstallerError {
            throw error
        } catch {
            throw AddonInstallerError.downloadFailed
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let redirectURL = request.url, InstallHostAllowlist.isAllowed(redirectURL) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
