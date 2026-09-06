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
            let (tempURL, response) = try await session.download(from: url)
            try Self.requireSuccess(response)
            return tempURL
        } catch let error as AddonInstallerError {
            throw error
        } catch {
            throw AddonInstallerError.downloadFailed
        }
    }

    /// Rejects cancelled-redirect leftovers (empty 302 body) instead of hashing them.
    public static func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
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
