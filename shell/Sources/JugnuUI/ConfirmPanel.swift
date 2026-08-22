import AppKit
import JugnuCore
import SwiftUI

@MainActor
public final class ConfirmPanel: KeyablePanel {
    private let errorState = PanelErrorState()
    private let onCancel: () -> Void

    public init(ui: UIDescriptor, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        contentView = NSHostingView(
            rootView: ThemedPanelBackground {
                ConfirmView(ui: ui, errorState: errorState, onConfirm: onConfirm, onCancel: onCancel)
            }
        )
        center()
    }

    public func presentError(_ message: String) {
        errorState.message = message
    }

    override public func cancelOperation(_ sender: Any?) { onCancel() }
}

private struct ConfirmView: View {
    let ui: UIDescriptor
    @ObservedObject var errorState: PanelErrorState
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Text(ui.title ?? "Confirm")
                .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
            Text(ui.message ?? "")
                .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                .foregroundStyle(theme.textSecondary)
            if let message = errorState.message {
                PanelErrorBanner(message: message)
            }
            HStack {
                Spacer()
                Button(ui.cancelLabel ?? "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(ui.confirmLabel ?? "Confirm", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
