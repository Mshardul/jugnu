import AppKit
import JugnuCore
import SwiftUI

public func favoritesSlots<T>(from items: [T], limit: Int) -> (shown: [T], hasMore: Bool) {
    guard items.count > limit else { return (items, false) }
    return (Array(items.prefix(limit)), true)
}

public struct FavoritesRow: View {
    let favorites: [IndexedCommand]
    let onRun: (IndexedCommand) -> Void
    let onReorder: (Int, Int) -> Void
    let onRemove: (IndexedCommand) -> Void
    let onOpenAllFavorites: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared
    @State private var draggingID: String?

    public init(
        favorites: [IndexedCommand],
        onRun: @escaping (IndexedCommand) -> Void,
        onReorder: @escaping (Int, Int) -> Void,
        onRemove: @escaping (IndexedCommand) -> Void,
        onOpenAllFavorites: @escaping () -> Void
    ) {
        self.favorites = favorites
        self.onRun = onRun
        self.onReorder = onReorder
        self.onRemove = onRemove
        self.onOpenAllFavorites = onOpenAllFavorites
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
    }

    public var body: some View {
        let slots = favoritesSlots(from: favorites, limit: 5)
        HStack(spacing: JugnuTokens.Launcher.favSpacing) {
            Spacer(minLength: 0)
            ForEach(Array(slots.shown.enumerated()), id: \.element.qualifiedId) { index, command in
                favoriteIcon(command)
                    .onTapGesture { onRun(command) }
                    .contextMenu { Button("Remove from Favorites") { onRemove(command) } }
                    .onDrag {
                        draggingID = command.qualifiedId
                        return NSItemProvider(object: command.qualifiedId as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: FavoriteDropDelegate(
                            targetIndex: index,
                            favorites: slots.shown,
                            draggingID: $draggingID,
                            onReorder: onReorder
                        )
                    )
            }
            if slots.hasMore {
                Button(action: onOpenAllFavorites) {
                    Text("···")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: JugnuTokens.Launcher.favTile, height: JugnuTokens.Launcher.favTile)
                }
                .buttonStyle(.plain)
                .help("All favorites")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func favoriteIcon(_ command: IndexedCommand) -> some View {
        RoundedRectangle(cornerRadius: JugnuTokens.Launcher.favTileRadius, style: .continuous)
            .fill(theme.accent.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: JugnuTokens.Launcher.favTileRadius, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: JugnuTokens.Launcher.hairline)
            )
            .overlay(
                Text(String(command.title.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
            )
            .frame(width: JugnuTokens.Launcher.favTile, height: JugnuTokens.Launcher.favTile)
            .shadow(color: theme.accent.opacity(0.45), radius: 4)
            .help(command.title)
    }
}

private struct FavoriteDropDelegate: DropDelegate {
    let targetIndex: Int
    let favorites: [IndexedCommand]
    @Binding var draggingID: String?
    let onReorder: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              let sourceIndex = favorites.firstIndex(where: { $0.qualifiedId == draggingID }),
              sourceIndex != targetIndex
        else { return }
        onReorder(sourceIndex, targetIndex)
    }
}

public struct JugnuWordmark: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init() {}

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.white.opacity(0.95), theme.accent, theme.accent.opacity(0)]),
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 16, height: 16)
                .shadow(color: theme.accent.opacity(0.55), radius: 5)
            Text("Jugnu")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.textPrimary)
        }
    }
}
