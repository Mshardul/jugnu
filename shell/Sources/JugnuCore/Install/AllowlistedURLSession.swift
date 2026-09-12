import Foundation

/// redirect hops are confined to InstallHostAllowlist, not just the initial URL
public final class AllowlistedDownloadSession: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    override public init() {
        super.init()
    }

    /// caller owns cleanup of the returned temp file
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

    /// an empty 302 body is a cancelled redirect leftover — reject instead of hashing it
    public static func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw AddonInstallerError.downloadFailed
        }
    }

    public func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
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
