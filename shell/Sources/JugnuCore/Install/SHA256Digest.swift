import CryptoKit
import Foundation

/// The one sha256 gate for addon, helper, and app packages. A registry row whose digest is not 64 hex
/// characters (placeholder, truncated, all zeros) counts as missing, so it fails before any download.
public enum SHA256Digest {
    public static func isWellFormed(_ hex: String) -> Bool {
        let lower = hex.lowercased()
        return lower.count == 64
            && lower.allSatisfy { ("0" ... "9").contains($0) || ("a" ... "f").contains($0) }
            && lower.contains { $0 != "0" }
    }

    @discardableResult
    public static func requireWellFormed(_ expected: String?) throws -> String {
        guard let expected, isWellFormed(expected) else {
            throw AddonInstallerError.sha256Required
        }
        return expected.lowercased()
    }

    public static func verify(_ expected: String?, file url: URL) throws {
        let expected = try requireWellFormed(expected)
        let actual = try SHA256.hash(data: Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw AddonInstallerError.sha256Mismatch(expected: expected, actual: actual)
        }
    }
}
