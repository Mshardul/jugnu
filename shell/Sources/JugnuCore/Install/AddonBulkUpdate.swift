import Foundation

public enum AddonBulkUpdate {
    public static func outdated(
        installed: [String: String],
        catalog: [RegistryEntry]
    ) -> [RegistryEntry] {
        catalog.filter { entry in
            AddonUpdate.isAvailable(installed: installed[entry.id], registry: entry.version)
        }
    }
}
