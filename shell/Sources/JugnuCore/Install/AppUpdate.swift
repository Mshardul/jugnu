import Foundation

public enum AppUpdateAvailability: Equatable {
    case upToDate
    case available(AppRegistryEntry)
    case blockedMacOS(required: String)
}

public enum AppUpdate {
    public static func availability(
        running: String,
        registry: AppRegistryEntry,
        osMajor: Int,
        osMinor: Int
    ) -> AppUpdateAvailability {
        guard PackageGates.isValidSemVer(running), PackageGates.isValidSemVer(registry.version) else {
            return .upToDate
        }
        if PackageGates.compareSemVer(running, registry.version) != .orderedAscending {
            return .upToDate
        }
        if osTooOld(minMacOS: registry.minMacOS, osMajor: osMajor, osMinor: osMinor) {
            return .blockedMacOS(required: registry.minMacOS)
        }
        return .available(registry)
    }

    static func osTooOld(minMacOS: String, osMajor: Int, osMinor: Int) -> Bool {
        let parts = minMacOS.split(separator: ".").compactMap { Int($0) }
        let reqMajor = parts.first ?? 0
        let reqMinor = parts.count > 1 ? parts[1] : 0
        if osMajor < reqMajor {
            return true
        }
        if osMajor > reqMajor {
            return false
        }
        return osMinor < reqMinor
    }
}
