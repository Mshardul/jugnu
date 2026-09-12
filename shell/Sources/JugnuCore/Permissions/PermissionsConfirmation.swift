import Foundation

public func confirmPermissionsInstallUI(addonName: String, permissions: [AddonPermission]) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Install \(addonName)?",
        message: "This addon will need:\n" + bulletList(permissions),
        confirmLabel: "Install",
        cancelLabel: "Cancel"
    )
}

public func confirmPermissionsMultiUI(
    expand: [(permission: AddonPermission, addonNames: [String])]
) -> UIDescriptor {
    var lines = ["They will need:"]
    for row in expand {
        lines.append(row.permission.displayTitle)
        for name in row.addonNames {
            lines.append("  • \(name)")
        }
    }
    return UIDescriptor(
        pattern: .confirm,
        title: "Install these addons?",
        message: lines.joined(separator: "\n"),
        confirmLabel: "Install",
        cancelLabel: "Cancel"
    )
}

public func confirmPermissionsGrewUI(addonName: String, newPermissions: [AddonPermission]) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Update \(addonName)?",
        message: "This version newly needs:\n" + bulletList(newPermissions),
        confirmLabel: "Update",
        cancelLabel: "Cancel"
    )
}

public func confirmInstallDisclosureUI(
    permissionsTitle: String,
    permissionsBody: String?,
    dependencyPlan: DependencyPlan?,
    confirmLabel: String = "Install"
) -> UIDescriptor {
    var parts: [String] = []
    if let permissionsBody, !permissionsBody.isEmpty {
        parts.append(permissionsBody)
    }
    if let plan = dependencyPlan, plan.needsDisclosure {
        var depLines = ["This will also handle these addons:"]
        for dep in plan.dependencies {
            switch dep.status {
            case .alreadyInstalled:
                depLines.append("• \(dep.name) — already installed")
            case .willInstall:
                depLines.append("• \(dep.name) — will be installed now")
            }
        }
        depLines.append("")
        depLines.append("Installed is not the same as enabled. You’ll enable each addon yourself.")
        parts.append(depLines.joined(separator: "\n"))
    }
    return UIDescriptor(
        pattern: .confirm,
        title: permissionsTitle,
        message: parts.joined(separator: "\n\n"),
        confirmLabel: confirmLabel,
        cancelLabel: "Cancel"
    )
}

public func confirmPreTCCExplainerUI(
    addonName: String,
    permission: AddonPermission
) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: addonName,
        message: "\(addonName) needs \(permission.displayTitle) to \(permission.reason).",
        confirmLabel: "Open System Settings",
        cancelLabel: "Not now"
    )
}

private func bulletList(_ permissions: [AddonPermission]) -> String {
    PermissionsSet.sort(permissions).map { "• \($0.displayTitle)" }.joined(separator: "\n")
}
