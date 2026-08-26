import AppKit
import SwiftUI

enum PanelChrome {
    static func borderless(size: NSSize, content: some View) -> KeyablePanel {
        let hosting = NSHostingView(rootView: content)
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        panel.center()
        return panel
    }
}

struct ThemedPanelBackground<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        content
            .environment(\.jugnuTheme, theme)
            .font(JugnuTokens.font(presetId: store.presetId, role: .body))
            .foregroundStyle(theme.textPrimary)
            .padding(JugnuTokens.Spacing.panelPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.25))
            )
    }
}
