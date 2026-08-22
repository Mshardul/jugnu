import AppKit
import JugnuCore

/// Always-on-top scratchpad panel. Unlike Form/List/Confirm, this panel stays
/// open across saves — closing (or Cmd+S) is what triggers persistence, not a
/// one-shot submit/dismiss cycle.
@MainActor
public final class NotePanel: NSPanel, NSWindowDelegate {
    private let onSave: (String) -> Void
    private let onClose: () -> Void
    private let textView: NSTextView

    public init(
        ui: UIDescriptor,
        onSave: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onClose = onClose
        let scrollView = NSTextView.scrollableTextView()
        self.textView = scrollView.documentView as! NSTextView
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = ui.title ?? "Scratch"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        delegate = self

        textView.string = ui.content ?? ""
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView = NSView()
        contentView?.addSubview(scrollView)
        if let cv = contentView {
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: cv.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            ])
        }
        center()
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            save()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func save() {
        onSave(textView.string)
    }

    public func windowWillClose(_ notification: Notification) {
        save()
        onClose()
    }

    public override func cancelOperation(_ sender: Any?) {
        close()
    }
}
