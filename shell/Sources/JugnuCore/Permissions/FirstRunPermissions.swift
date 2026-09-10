import Foundation

public enum FirstRunPermissions {
    public static func expand(
        entries: [RegistryEntry],
        selectedIDs: Set<String>
    ) -> [(permission: AddonPermission, addonNames: [String])] {
        let selected = entries.filter { selectedIDs.contains($0.id) }
        return PermissionsSet.unionExpand(
            addons: selected.map { (name: $0.name, permissions: $0.permissions) }
        )
    }

    public static func confirmMessage(
        expand: [(permission: AddonPermission, addonNames: [String])]
    ) -> String {
        confirmPermissionsMultiUI(expand: expand).message ?? ""
    }
}
