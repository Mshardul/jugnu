import JugnuCore
import SwiftUI

struct HomeGridView: View {
    var layout: HomeLayoutSnapshot?
    var linesByDefinition: [String: [String]]
    var acceptsTyping: Bool
    var onOpenCatalog: () -> Void
    var onTypeToSearch: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
        let palette = ShellPalette(theme: theme, colorScheme: colorScheme)
        Group {
            if let layout {
                placedHome(layout, palette: palette)
            } else {
                withheldHome(palette)
            }
        }
        .focusable(acceptsTyping)
        .onKeyPress(phases: .down) { press in
            guard acceptsTyping else { return .ignored }
            guard press.modifiers.isEmpty, let query = appShellTypeToSearchQuery(press.characters) else {
                return .ignored
            }
            onTypeToSearch(query)
            return .handled
        }
    }

    private func placedHome(_ layout: HomeLayoutSnapshot, palette: ShellPalette) -> some View {
        GeometryReader { geo in
            let width = max(geo.size.width - 48, 0)
            let placed = placedHomeWidgets(
                layout: layout,
                definitions: builtInWidgetDefinitions(),
                contentWidth: width
            )
            let height = placed.map(\.frame.maxY).max() ?? 0
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HomeIntro(palette: palette)
                    HomeWidgetCanvas(
                        placed: placed,
                        linesByDefinition: linesByDefinition,
                        palette: palette,
                        onOpenCatalog: onOpenCatalog
                    )
                    .frame(width: width, height: height, alignment: .topLeading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private func withheldHome(_ palette: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Home was saved by a newer Jugnu.")
                .font(.system(size: 16, weight: .semibold))
            Text("It was left unchanged.")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }
}

private struct HomeIntro: View {
    var palette: ShellPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(homeGreeting())
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(palette.text)
                .tracking(-0.4)
            Text("Your Addons, current work, and recent activity at a glance.")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
        }
    }
}

private struct HomeWidgetCanvas: View {
    var placed: [PlacedHomeWidget]
    var linesByDefinition: [String: [String]]
    var palette: ShellPalette
    var onOpenCatalog: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(placed, id: \.id) { widget in
                HomeWidgetCard(
                    widget: widget,
                    lines: linesByDefinition[widget.definitionID] ?? [],
                    palette: palette,
                    onOpenCatalog: onOpenCatalog
                )
                .frame(width: widget.frame.width, height: widget.frame.height)
                .offset(x: widget.frame.minX, y: widget.frame.minY)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }
}

private struct HomeWidgetCard: View {
    var widget: PlacedHomeWidget
    var lines: [String]
    var palette: ShellPalette
    var onOpenCatalog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(widget.name)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ShellGlyphTile(systemName: homeWidgetSymbol(widget.definitionID), palette: palette)
            Text(widget.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.text)
            Spacer(minLength: 0)
            if !lines.isEmpty {
                Text("\(lines.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.muted)
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if widget.definitionID == BuiltInWidget.updates, lines.isEmpty {
            UpdatesCurrent(palette: palette, onOpenCatalog: onOpenCatalog)
        } else if lines.isEmpty {
            HomeEmptyState(copy: emptyCopy(widget.definitionID), palette: palette)
        } else if widget.definitionID == BuiltInWidget.favoriteAddons {
            FavoriteTiles(lines: lines, palette: palette)
        } else {
            ActivityRows(lines: lines, symbol: homeWidgetSymbol(widget.definitionID), palette: palette)
        }
    }

    private func emptyCopy(_ definitionID: String) -> (title: String, detail: String) {
        switch definitionID {
        case BuiltInWidget.favoriteAddons:
            ("No favorites yet", "Favorite an Addon in Catalog to keep it here.")
        case BuiltInWidget.recentActivity:
            ("Nothing here yet", "Actions you run will appear here.")
        case BuiltInWidget.runningWork:
            ("Nothing running", "Installs, updates, and scheduled refresh show up here.")
        default:
            ("Nothing here yet", "")
        }
    }
}

private struct HomeEmptyState: View {
    var copy: (title: String, detail: String)
    var palette: ShellPalette

    var body: some View {
        VStack(spacing: 5) {
            Text(copy.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.sub)
            Text(copy.detail)
                .font(.system(size: 9.5))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

private struct FavoriteTiles: View {
    var lines: [String]
    var palette: ShellPalette

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 8) {
                    ShellGlyphTile(systemName: "star", palette: palette)
                    Text(line)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.soft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                )
            }
        }
    }
}

private struct ActivityRows: View {
    var lines: [String]
    var symbol: String
    var palette: ShellPalette

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 10) {
                    ShellGlyphTile(systemName: symbol, palette: palette)
                    Text(line)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 41)
                .overlay(alignment: .top) {
                    if index > 0 {
                        Rectangle().fill(palette.border).frame(height: 1)
                    }
                }
            }
        }
    }
}

private struct UpdatesCurrent: View {
    var palette: ShellPalette
    var onOpenCatalog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("0")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text("Everything is current")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.muted)
                }
                Spacer(minLength: 8)
                Button("Browse Catalog", action: onOpenCatalog)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(palette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(palette.accent.opacity(0.45), lineWidth: 1)
                    )
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(palette.status)
                    .frame(width: 7, height: 7)
                    .shadow(color: palette.status.opacity(0.7), radius: 3)
                Text("Checked just now")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
            }
        }
    }
}
