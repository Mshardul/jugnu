import AppKit
import JugnuCore
import SwiftUI

public struct GridPanelView: View {
    let ui: UIDescriptor
    @ObservedObject var errorState: PanelErrorState
    var onSelect: (UIGridItem, String?) -> Void
    var onCancel: () -> Void

    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        ui: UIDescriptor,
        errorState: PanelErrorState,
        onSelect: @escaping (UIGridItem, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.ui = ui
        self.errorState = errorState
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    private var items: [UIGridItem] {
        ui.gridItems ?? []
    }

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: JugnuTokens.Spacing.row)]

    public var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Text(ui.title ?? "Audio")
                .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
            if let message = errorState.message {
                PanelErrorBanner(message: message)
            }
            LazyVGrid(columns: columns, spacing: JugnuTokens.Spacing.row) {
                ForEach(items, id: \.id) { item in
                    Button {
                        onSelect(item, item.actions?.first ?? "select")
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(item.active ? theme.accent : theme.textSecondary)
                            Text(item.title)
                                .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                                .foregroundStyle(theme.textPrimary)
                            if let subtitle = item.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.active ? theme.accent.opacity(0.15) : theme.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    item.active ? theme.accent : theme.textSecondary.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}
