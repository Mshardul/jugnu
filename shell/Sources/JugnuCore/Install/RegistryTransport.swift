import Foundation

final class RegistryTransport: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let maxBytes = 5_000_000
    static let shared = RegistryTransport()

    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    static func isAllowed(_ url: URL) -> Bool {
        // registry JSON carries every sha256, so it is confined like downloads; `file` stays for local registries
        let scheme = url.scheme?.lowercased()
        return scheme == "https" || scheme == "file"
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard Self.isAllowed(url) else { throw RegistryClientError.insecureURL }
        let (bytes, response) = try await session.bytes(from: url)
        if response.expectedContentLength > Int64(Self.maxBytes) {
            throw RegistryClientError.tooLarge
        }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > Self.maxBytes {
                throw RegistryClientError.tooLarge
            }
        }
        return (data, response)
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let target = request.url, target.scheme?.lowercased() == "https" else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
