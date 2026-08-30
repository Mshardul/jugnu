import AppKit
import JugnuCore
import SwiftUI

@MainActor
public protocol PaletteModelProtocol: ObservableObject {
    var allCommands: [IndexedCommand] { get }
    var lastHits: [SearchHit] { get }
    var statusMessage: String? { get }
    var hiddenShellCommands: Set<String> { get }
    var shellNativeCommands: [ShellNativeCommand] { get }

    func commandsForFirstView() -> [IndexedCommand]
    func search(_ query: String) -> [IndexedCommand]
    func isFavorite(qualifiedId: String) -> Bool
    func toggleFavorite(qualifiedId: String)
}

/// A mashing user's repeat invoke of the same command inside the window collapses to one spawn.
public enum PaletteInvokeDebounce {
    public static let windowSeconds: TimeInterval = 0.1

    public static func shouldRun(id: String, now: Date, last: (id: String, at: Date)?) -> Bool {
        guard let last, last.id == id else { return true }
        return now.timeIntervalSince(last.at) >= windowSeconds
    }
}

public struct PaletteView<Model: PaletteModelProtocol>: View {
    @ObservedObject var model: Model
    var favorites: [IndexedCommand]
    var onRun: (IndexedCommand) -> Void
    var onClose: () -> Void
    var onOpenBrowseCatalog: () -> Void
    var onOpenPreferences: () -> Void
    var onRunShellNative: (ShellNativeCommand) -> Void
    var onStateChange: (ShellViewState) -> Void
    var onReorderFavorite: (Int, Int) -> Void
    var onRemoveFavorite: (IndexedCommand) -> Void

    @State private var query: String
    @State private var selection = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var lastInvoke: (id: String, at: Date)?
    @State private var hintIndex = 0
    @State private var bloom: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(
        model: Model,
        favorites: [IndexedCommand] = [],
        initialQuery: String = "",
        onRun: @escaping (IndexedCommand) -> Void,
        onClose: @escaping () -> Void,
        onOpenBrowseCatalog: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void,
        onRunShellNative: @escaping (ShellNativeCommand) -> Void = { _ in },
        onStateChange: @escaping (ShellViewState) -> Void = { _ in },
        onReorderFavorite: @escaping (Int, Int) -> Void = { _, _ in },
        onRemoveFavorite: @escaping (IndexedCommand) -> Void = { _ in }
    ) {
        self.model = model
        self.favorites = favorites
        self.onRun = onRun
        self.onClose = onClose
        self.onOpenBrowseCatalog = onOpenBrowseCatalog
        self.onOpenPreferences = onOpenPreferences
        self.onRunShellNative = onRunShellNative
        self.onStateChange = onStateChange
        self.onReorderFavorite = onReorderFavorite
        self.onRemoveFavorite = onRemoveFavorite
        _query = State(initialValue: initialQuery)
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
    }

    private func pillBackground(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: JugnuTokens.Launcher.hairline)
            )
    }

    private var displayed: [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return model.commandsForFirstView().map {
                SearchHit(command: $0, tier: .title, score: 0, isSuggestion: false)
            }
        }
        return model.lastHits
    }

    /// Shell-native rows sit below addon hits: all of them on an empty query, fuzzy-matched otherwise.
    private var displayedShellNative: [ShellNativeCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return model.shellNativeCommands
        }
        return model.shellNativeCommands
            .map { ($0, $0.matchScore(query: trimmed)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private var selectableCount: Int {
        displayed.count + displayedShellNative.count
    }

    private func debouncedRun(_ command: IndexedCommand) {
        let now = Date()
        guard PaletteInvokeDebounce.shouldRun(id: command.qualifiedId, now: now, last: lastInvoke) else { return }
        lastInvoke = (command.qualifiedId, now)
        onRun(command)
    }

    private func runSelection() {
        switch LauncherSelection.resolve(
            index: selection,
            addonCount: displayed.count,
            shellNativeCount: displayedShellNative.count
        ) {
        case let .addon(i): debouncedRun(displayed[i].command)
        case let .shellNative(i): onRunShellNative(displayedShellNative[i])
        case .none: break
        }
    }

    private var placeholder: String {
        if model.allCommands.isEmpty {
            return "No addons yet — install some to get started."
        }
        let commands = model.allCommands
        guard !commands.isEmpty else { return "Search commands" }
        let cmd = commands[hintIndex % commands.count]
        let hint = cmd.keywords.first ?? cmd.title.split(separator: " ").prefix(2).joined(separator: " ")
        return "Try '\(hint)'…"
    }

    public var body: some View {
        let L = JugnuTokens.Launcher.self
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                JugnuWordmark()
                FavoritesRow(
                    favorites: favorites,
                    onRun: debouncedRun,
                    onReorder: onReorderFavorite,
                    onRemove: onRemoveFavorite,
                    onOpenAllFavorites: { onOpenBrowseCatalog() }
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, L.edgeInset)
            .frame(height: L.row1Height)
            .overlay(alignment: .bottom) { theme.border.frame(height: L.hairline) }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField(placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(JugnuTokens.font(presetId: themeStore.presetId, role: .callout))
                    .onChange(of: query) { _, newValue in
                        onStateChange(.launcher(query: newValue, selection: nil, scroll: 0))
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            guard !Task.isCancelled else { return }
                            _ = model.search(newValue)
                            selection = 0
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(pillBackground(radius: L.searchRadius))
            .padding(.horizontal, L.edgeInset)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { theme.border.frame(height: L.hairline) }

            SearchResultsRegion(
                hits: displayed,
                shellNativeRows: displayedShellNative,
                selection: selection,
                onSelect: debouncedRun,
                onSelectShellNative: onRunShellNative,
                onOpenBrowseCatalog: { onOpenBrowseCatalog() },
                isFavorite: { model.isFavorite(qualifiedId: $0.qualifiedId) },
                onToggleFavorite: { model.toggleFavorite(qualifiedId: $0.qualifiedId) }
            )

            if let status = model.statusMessage {
                PanelErrorBanner(message: status)
                    .padding(.horizontal, L.edgeInset)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: L.panelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.2 + bloom * 0.5), lineWidth: 1.5)
                .shadow(color: theme.accent.opacity(bloom), radius: 18)
        )
        .focusable()
        .onAppear {
            _ = model.search(query)
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                withAnimation(.easeOut(duration: 0.12)) { bloom = 0.35 }
                withAnimation(.easeIn(duration: 0.18).delay(0.12)) { bloom = 0 }
            }
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if query.isEmpty, !model.allCommands.isEmpty {
                hintIndex += 1
            }
        }
        .onKeyPress(.return) {
            runSelection()
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectableCount > 0 {
                selection = min(selection + 1, selectableCount - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
    }
}
