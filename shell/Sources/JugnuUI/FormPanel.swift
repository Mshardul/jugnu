import AppKit
import JugnuCore

@MainActor
public final class FormPanel: NSPanel {
    private let onSubmit: ([String: JSONValue]) -> Void
    private let onCancel: () -> Void
    private let fields: [UIFormField]
    private var inputs: [String: NSView] = [:]

    public init(
        ui: UIDescriptor,
        onSubmit: @escaping ([String: JSONValue]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.fields = ui.fields ?? []
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = ui.title ?? "Form"
        isFloatingPanel = true
        level = .floating

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for field in fields {
            let label = NSTextField(labelWithString: field.label)
            stack.addArrangedSubview(label)
            switch field.kind {
            case "toggle":
                let toggle = NSSwitch()
                if case .bool(let b) = field.value { toggle.state = b ? .on : .off }
                inputs[field.id] = toggle
                stack.addArrangedSubview(toggle)
            default:
                let text = NSTextField(string: {
                    if case .string(let s) = field.value { return s }
                    return ""
                }())
                text.placeholderString = field.label
                inputs[field.id] = text
                stack.addArrangedSubview(text)
            }
        }

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        let submit = NSButton(title: "Submit", target: self, action: #selector(submitTapped))
        submit.keyEquivalent = "\r"
        buttons.addArrangedSubview(NSView())
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(submit)
        stack.addArrangedSubview(buttons)

        let root = NSView()
        root.addSubview(stack)
        contentView = root
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -16),
        ])
        center()
    }

    @objc private func submitTapped() {
        var values: [String: JSONValue] = [:]
        for field in fields {
            guard let view = inputs[field.id] else { continue }
            if let toggle = view as? NSSwitch {
                values[field.id] = .bool(toggle.state == .on)
            } else if let text = view as? NSTextField {
                values[field.id] = .string(text.stringValue)
            }
        }
        onSubmit(values)
    }

    @objc private func cancelTapped() { onCancel() }
    public override func cancelOperation(_ sender: Any?) { onCancel() }
}
