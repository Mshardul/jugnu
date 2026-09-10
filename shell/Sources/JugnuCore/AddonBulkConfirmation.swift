import Foundation

public func confirmAddonBulkUI(
    count: Int,
    growthExpand: [(permission: AddonPermission, addonNames: [String])] = []
) -> UIDescriptor {
    let base = "\(count) addons have updates. Update all?"
    let message: String
    if growthExpand.isEmpty {
        message = base
    } else {
        var lines: [String] = [base, "", "Some updates newly need:"]
        for row in growthExpand {
            lines.append(row.permission.displayTitle)
            lines.append(contentsOf: row.addonNames.map { "  • \($0)" })
        }
        message = lines.joined(separator: "\n")
    }
    return UIDescriptor(
        pattern: .confirm,
        title: "Update addons?",
        message: message,
        confirmLabel: "Update",
        cancelLabel: "Later"
    )
}

public enum AddonBulkPermissions {
    public static func growthExpand(
        outdated: [RegistryEntry],
        installedPermissions: (String) -> [AddonPermission]
    ) -> [(permission: AddonPermission, addonNames: [String])] {
        PermissionsSet.unionExpand(
            addons: outdated.map { entry in
                (
                    name: entry.name,
                    permissions: PermissionsSet.grew(
                        from: installedPermissions(entry.id),
                        to: entry.permissions
                    )
                )
            }
        )
    }
}
