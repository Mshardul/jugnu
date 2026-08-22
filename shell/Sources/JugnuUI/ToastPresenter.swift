import AppKit

@MainActor
public final class ToastPresenter {
    private var window: NSPanel?
    private var hideWork: DispatchWorkItem?

    public init() {}

    public func show(message: String, isError: Bool) {
        hideWork?.cancel()
        window?.close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let label = NSTextField(labelWithString: message)
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        let box = NSView(frame: .zero)
        box.wantsLayer = true
        box.layer?.cornerRadius = 10
        box.layer?.backgroundColor = (isError ? NSColor.systemRed : NSColor.black.withAlphaComponent(0.82)).cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
        ])

        panel.contentView = box
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - 160
            let y = screen.visibleFrame.maxY - 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFront(nil)
        window = panel

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let work = DispatchWorkItem { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 1.2 : 1.5), execute: work)
    }
}
