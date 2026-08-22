import AppKit
import JugnuCore
import SwiftUI

@MainActor
public final class SkeletonPanel: KeyablePanel {
    public init(pattern: UIPattern, title: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        contentView = NSHostingView(
            rootView: ThemedPanelBackground {
                VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
                    Text(title)
                        .font(.headline)
                    Text("Loading \(pattern.rawValue)…")
                        .foregroundStyle(.secondary)
                }
            }
        )
        center()
    }
}
