import AppKit
import SwiftUI

@MainActor
public final class ToastPresenter {
    private var window: NSPanel?
    private var hideWork: DispatchWorkItem?

    public init() {}

    public func show(message: String, isError: Bool) {
        hideWork?.cancel()
        window?.close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: ToastView(message: message, isError: isError))

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let x = screen.visibleFrame.midX - 160
            let y = screen.visibleFrame.maxY - 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
        panel.orderFront(nil)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
        window = panel
        playCommandSound(success: !isError)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let work = DispatchWorkItem { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 1.2 : 1.5), execute: work)
    }
}

private struct ToastView: View {
    let message: String
    let isError: Bool
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        HStack(spacing: 8) {
            Image("AppIcon")
                .resizable()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(message)
                .font(JugnuTokens.font(presetId: store.presetId, role: .callout))
                .foregroundStyle(isError ? Color.white : theme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(isError ? theme.error : theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
