import AppKit
import JugnuCore

@MainActor
public final class SkeletonPanel: NSPanel {
    public init(pattern: UIPattern, title: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        self.title = title
        isFloatingPanel = true
        level = .floating

        let label = NSTextField(labelWithString: "Loading \(pattern.rawValue)…")
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        let root = NSView()
        root.addSubview(label)
        contentView = root
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        center()
    }
}
