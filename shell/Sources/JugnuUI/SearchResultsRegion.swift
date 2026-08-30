import Foundation
import JugnuCore
import SwiftUI

public struct ResultSlotLayout<T> {
    public let rows: [T]
    public let showAllLinkSlot: Int?
    public let scrolls: Bool

    public init(rows: [T], showAllLinkSlot: Int?, scrolls: Bool) {
        self.rows = rows
        self.showAllLinkSlot = showAllLinkSlot
        self.scrolls = scrolls
    }
}

public func resultSlots<T>(results: [T], slotCount: Int) -> ResultSlotLayout<T> {
    let maxRowsWithLinkRoom = slotCount - 1
    if results.count <= maxRowsWithLinkRoom {
        return ResultSlotLayout(rows: results, showAllLinkSlot: results.isEmpty ? nil : slotCount, scrolls: false)
    }
    return ResultSlotLayout(rows: results, showAllLinkSlot: nil, scrolls: true)
}

/// Unified up/down selection: addon hits first, shell-native rows after.
public enum LauncherSelection: Equatable {
    case addon(Int)
    case shellNative(Int)
    case none

    public static func resolve(index: Int, addonCount: Int, shellNativeCount: Int) -> LauncherSelection {
        if index >= 0, index < addonCount {
            return .addon(index)
        }
        let shellIndex = index - addonCount
        if shellIndex >= 0, shellIndex < shellNativeCount {
            return .shellNative(shellIndex)
        }
        return .none
    }
}

public struct SearchResultsRegion: View {
    let hits: [SearchHit]
    let shellNativeRows: [ShellNativeCommand]
    let selection: Int
    let onSelect: (IndexedCommand) -> Void
    let onSelectShellNative: (ShellNativeCommand) -> Void
    let onOpenBrowseCatalog: () -> Void
    let isFavorite: (IndexedCommand) -> Bool
    let onToggleFavorite: (IndexedCommand) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        hits: [SearchHit],
        shellNativeRows: [ShellNativeCommand] = [],
        selection: Int,
        onSelect: @escaping (IndexedCommand) -> Void,
        onSelectShellNative: @escaping (ShellNativeCommand) -> Void = { _ in },
        onOpenBrowseCatalog: @escaping () -> Void,
        isFavorite: @escaping (IndexedCommand) -> Bool,
        onToggleFavorite: @escaping (IndexedCommand) -> Void
    ) {
        self.hits = hits
        self.shellNativeRows = shellNativeRows
        self.selection = selection
        self.onSelect = onSelect
        self.onSelectShellNative = onSelectShellNative
        self.onOpenBrowseCatalog = onOpenBrowseCatalog
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
    }

    private var slotCount: Int {
        JugnuTokens.Launcher.resultSlotCount
    }

    private var rowHeight: CGFloat {
        JugnuTokens.Launcher.resultRowHeight
    }

    public var body: some View {
        let layout = resultSlots(results: hits, slotCount: slotCount)
        if !layout.rows.isEmpty || !shellNativeRows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if !layout.rows.isEmpty {
                    addonBlock(layout: layout)
                }
                if !shellNativeRows.isEmpty {
                    shellNativeBlock(base: layout.rows.count)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func addonBlock(layout: ResultSlotLayout<SearchHit>) -> some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(layout.rows.enumerated()), id: \.element.command.qualifiedId) { index, hit in
                breadcrumbRow(hit: hit, isSelected: index == selection)
            }
            // Blank reserved slots keep slot 5 from sliding up (spec §2.1).
            if let linkSlot = layout.showAllLinkSlot {
                let blankSlots = linkSlot - 1 - layout.rows.count
                ForEach(0 ..< max(blankSlots, 0), id: \.self) { _ in
                    Color.clear.frame(height: rowHeight)
                }
                showAllRow
            }
        }
        if layout.scrolls {
            ScrollView { content }
                .frame(height: rowHeight * CGFloat(slotCount))
        } else {
            content
                .frame(height: rowHeight * CGFloat(slotCount), alignment: .top)
        }
    }

    private func shellNativeBlock(base: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            theme.border.frame(height: JugnuTokens.Launcher.hairline)
            ForEach(Array(shellNativeRows.enumerated()), id: \.element.id) { offset, cmd in
                shellNativeRow(cmd, isSelected: base + offset == selection)
            }
        }
    }

    private func shellNativeRow(_ cmd: ShellNativeCommand, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: JugnuTokens.Launcher.resultIconRadius, style: .continuous)
                .strokeBorder(theme.textSecondary.opacity(0.4), lineWidth: JugnuTokens.Launcher.hairline)
                .frame(width: JugnuTokens.Launcher.resultIcon, height: JugnuTokens.Launcher.resultIcon)
                .overlay(Image(systemName: cmd.systemImage).foregroundStyle(theme.textSecondary))
            Text(cmd.title)
                .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                .foregroundStyle(theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: JugnuTokens.Launcher.favTileRadius, style: .continuous)
                .fill(isSelected ? theme.accent.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelectShellNative(cmd) }
    }

    private func breadcrumbRow(hit: SearchHit, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: JugnuTokens.Launcher.resultIconRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [theme.accent, theme.accentDeep]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: JugnuTokens.Launcher.resultIcon, height: JugnuTokens.Launcher.resultIcon)
            (
                Text(hit.command.addonId).foregroundStyle(theme.textSecondary)
                    + Text(" › ").foregroundStyle(theme.textSecondary)
                    + Text(hit.isSuggestion ? "\(hit.command.title) (did you mean this?)" : hit.command.title)
                    .foregroundStyle(theme.textPrimary).bold()
            )
            .font(JugnuTokens.font(presetId: store.presetId, role: .body))
            Spacer()
            Button {
                onToggleFavorite(hit.command)
            } label: {
                Image(systemName: isFavorite(hit.command) ? "star.fill" : "star")
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("Pin to favorites")
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: JugnuTokens.Launcher.favTileRadius, style: .continuous)
                .fill(isSelected ? theme.accent.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect(hit.command) }
    }

    private var showAllRow: some View {
        Button(action: onOpenBrowseCatalog) {
            Text("Show all addons →")
                .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                .fontWeight(.bold)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .overlay(alignment: .top) { theme.border.frame(height: JugnuTokens.Launcher.hairline) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
