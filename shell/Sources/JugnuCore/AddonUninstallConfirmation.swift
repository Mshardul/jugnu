import Foundation

public func confirmUninstallUI(name: String) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Uninstall \(name)?",
        message: "This removes it and any local data it stored.",
        confirmLabel: "Uninstall",
        cancelLabel: "Cancel"
    )
}
