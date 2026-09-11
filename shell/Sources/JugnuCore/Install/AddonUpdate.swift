import Foundation

public enum AddonUpdate {
    public static func isAvailable(installed: String?, registry: String) -> Bool {
        guard let installed, PackageGates.isValidSemVer(installed), PackageGates.isValidSemVer(registry) else {
            return false
        }
        return PackageGates.compareSemVer(installed, registry) == .orderedAscending
    }
}
