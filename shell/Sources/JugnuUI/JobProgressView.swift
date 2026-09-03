import JugnuCore
import SwiftUI

public struct JobProgressView: View {
    var startedAt: Date
    var onCancel: () -> Void
    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    public init(startedAt: Date, onCancel: @escaping () -> Void) {
        self.startedAt = startedAt
        self.onCancel = onCancel
    }

    public var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(JobProgressCopy.label(elapsed: elapsed))
                    .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
            }
            .foregroundStyle(theme.textPrimary)
        }
    }
}
