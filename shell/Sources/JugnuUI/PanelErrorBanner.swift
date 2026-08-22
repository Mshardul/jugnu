import SwiftUI

public struct PanelErrorBanner: View {
    public var message: String
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        Text(message)
            .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
            .foregroundStyle(theme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(theme.error.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@MainActor
public final class PanelErrorState: ObservableObject {
    @Published public var message: String?

    public init() {}
}
