import Foundation

public func confirmAppUpdateUI(version: String, notes: String?) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Update Jugnu?",
        message: notes.map { "Jugnu \(version) is ready. Update and restart?\n\n\($0)" }
            ?? "Jugnu \(version) is ready. Update and restart?",
        confirmLabel: "Update and Restart",
        cancelLabel: "Later"
    )
}
