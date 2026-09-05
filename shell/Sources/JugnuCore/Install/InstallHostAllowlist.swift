import Foundation

public enum InstallHostAllowlist {
    public static let hosts: Set<String> = [
        "github.com",
        "objects.githubusercontent.com",
    ]

    /// Returns true when `url` is https and its host is on the allowlist.
    public static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains(host)
    }
}
