import Foundation

public func confirmAddonBulkUI(count: Int) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Update addons?",
        message: "\(count) addons have updates. Update all?",
        confirmLabel: "Update",
        cancelLabel: "Later"
    )
}
