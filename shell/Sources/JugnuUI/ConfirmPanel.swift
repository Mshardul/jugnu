import AppKit
import JugnuCore

@MainActor
public final class ConfirmPanel: NSPanel {
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    public init(ui: UIDescriptor, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = ui.title ?? "Confirm"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString: ui.message ?? "")
        body.maximumNumberOfLines = 4

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let cancel = NSButton(title: ui.cancelLabel ?? "Cancel", target: self, action: #selector(cancelTapped))
        let ok = NSButton(title: ui.confirmLabel ?? "Confirm", target: self, action: #selector(confirmTapped))
        ok.keyEquivalent = "\r"
        buttons.addArrangedSubview(NSView())
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(ok)

        stack.addArrangedSubview(body)
        stack.addArrangedSubview(buttons)
        contentView = NSView()
        contentView?.addSubview(stack)
        if let cv = contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
                stack.topAnchor.constraint(equalTo: cv.topAnchor, constant: 16),
                stack.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
            ])
        }
        center()
    }

    @objc private func confirmTapped() { onConfirm() }
    @objc private func cancelTapped() { onCancel() }

    public override func cancelOperation(_ sender: Any?) { onCancel() }
}
