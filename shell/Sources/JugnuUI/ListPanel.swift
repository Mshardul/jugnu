import AppKit
import JugnuCore
import SwiftUI

public struct ListPanelView: View {
    let ui: UIDescriptor
    @ObservedObject var errorState: PanelErrorState
    var onSelect: (UIListItem, String?) -> Void
    var onCancel: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        ui: UIDescriptor,
        errorState: PanelErrorState,
        onSelect: @escaping (UIListItem, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.ui = ui
        self.errorState = errorState
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    private var items: [UIListItem] { ui.items ?? [] }

    private var filtered: [UIListItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return items }
        return items.filter {
            $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Text(ui.title ?? "Choose")
                .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
            TextField(ui.placeholder ?? "Filter", text: $query)
                .textFieldStyle(.plain)
                .padding(6)
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: query) { _, _ in
                    selection = 0
                }
            if let message = errorState.message {
                PanelErrorBanner(message: message)
            }
            List(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                Button {
                    onSelect(item, item.actions?.first ?? "select")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .background(idx == selection ? theme.accent.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onKeyPress(.return) {
            guard filtered.indices.contains(selection) else { return .handled }
            let item = filtered[selection]
            onSelect(item, item.actions?.first ?? "select")
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !filtered.isEmpty {
                selection = min(selection + 1, filtered.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
    }
}
