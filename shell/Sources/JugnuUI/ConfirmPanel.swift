import AppKit
import JugnuCore
import SwiftUI

public struct ConfirmView: View {
    let ui: UIDescriptor
    @ObservedObject var errorState: PanelErrorState
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        ui: UIDescriptor,
        errorState: PanelErrorState,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.ui = ui
        self.errorState = errorState
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
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
