import AppKit
import JugnuCore
import SwiftUI

struct CardAccent: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#"), trimmed.count == 7 || trimmed.count == 9 else { return nil }
        guard let value = UInt64(trimmed.dropFirst(), radix: 16) else { return nil }

        if trimmed.count == 7 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        } else {
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        }
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

@MainActor
public final class CardPanel: NSPanel {
    private let lifecycle = CardPanelLifecycle()

    public init(ui: UIDescriptor, reduceMotion: Bool, onClose: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = ui.title ?? "Reminder"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        delegate = lifecycle
        lifecycle.onClose = onClose
        contentView = NSHostingView(rootView: CardPanelView(ui: ui, reduceMotion: reduceMotion))
        center()
    }

    public func replace(ui: UIDescriptor, reduceMotion: Bool) {
        title = ui.title ?? "Reminder"
        contentView = NSHostingView(rootView: CardPanelView(ui: ui, reduceMotion: reduceMotion))
    }

    public func dismissOnOutsideClick() {
        lifecycle.startOutsideClickMonitor(for: self) { [weak self] in
            Task { @MainActor in self?.close() }
        }
    }

    override public func cancelOperation(_: Any?) {
        close()
    }
}

@MainActor
private final class CardPanelLifecycle: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    func startOutsideClickMonitor(for window: NSWindow, onOutside: @escaping () -> Void) {
        stopOutsideClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            onOutside()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak window] event in
            if event.window !== window {
                onOutside()
            }
            return event
        }
    }

    func windowWillClose(_: Notification) {
        stopOutsideClickMonitor()
        onClose?()
    }

    private func stopOutsideClickMonitor() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
        globalClickMonitor = nil
        localClickMonitor = nil
    }
}

private struct CardPanelView: View {
    let ui: UIDescriptor
    let reduceMotion: Bool
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared
    @State private var isPresented: Bool

    init(ui: UIDescriptor, reduceMotion: Bool) {
        self.ui = ui
        self.reduceMotion = reduceMotion
        _isPresented = State(initialValue: reduceMotion)
    }

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        let wash = ui.accent.flatMap(CardAccent.init(hex:))?.color ?? theme.surface

        VStack(spacing: JugnuTokens.Spacing.panelPadding) {
            if let emoji = ui.emoji, emoji.isEmpty == false {
                Text(emoji)
                    .font(.system(size: 88))
                    .accessibilityLabel(ui.title ?? "Reminder")
            }
            Text(ui.message ?? "")
                .font(JugnuTokens.font(presetId: store.presetId, role: .title2))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textPrimary)
        }
        .padding(JugnuTokens.Spacing.panelPadding * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(wash.opacity(ui.accent == nil ? 1 : 0.24))
        .scaleEffect(isPresented ? 1 : 0.94)
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            guard reduceMotion == false else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isPresented = true
            }
        }
    }
}
