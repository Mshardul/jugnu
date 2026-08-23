import AppKit
import JugnuCore
import SwiftUI

@MainActor
public protocol PaletteModelProtocol: ObservableObject {
    var allCommands: [IndexedCommand] { get }
    var lastHits: [SearchHit] { get }
    var statusMessage: String? { get }

    func commandsForFirstView() -> [IndexedCommand]
    func search(_ query: String) -> [IndexedCommand]
    func isFavorite(qualifiedId: String) -> Bool
    func toggleFavorite(qualifiedId: String)
}

public struct PaletteView<Model: PaletteModelProtocol>: View {
    @ObservedObject var model: Model
    var onRun: (IndexedCommand) -> Void
    var onClose: () -> Void
    var onOpenBrowseCatalog: () -> Void
    var onStateChange: (ShellViewState) -> Void

    @State private var query: String
    @State private var selection = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var hintIndex = 0
    @State private var bloom: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(
        model: Model,
        initialQuery: String = "",
        onRun: @escaping (IndexedCommand) -> Void,
        onClose: @escaping () -> Void,
        onOpenBrowseCatalog: @escaping () -> Void,
        onStateChange: @escaping (ShellViewState) -> Void = { _ in }
    ) {
        self.model = model
        self.onRun = onRun
        self.onClose = onClose
        self.onOpenBrowseCatalog = onOpenBrowseCatalog
        self.onStateChange = onStateChange
        _query = State(initialValue: initialQuery)
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
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

    private var showBrowseCatalogRow: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title3))
                .padding(8)
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

            if showBrowseCatalogRow {
                Button {
                    onOpenBrowseCatalog()
                    onClose()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse Addons")
                                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .headline))
                            Text("Discover, install, and manage addons")
                                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .caption))
                                .foregroundStyle(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                Divider()
            }

            List(Array(displayed.enumerated()), id: \.element.command.qualifiedId) { idx, hit in
                HStack {
                    Button {
                        onRun(hit.command)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.command.title)
                                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .headline))
                            Text(hit.isSuggestion ? "Did you mean this?" : hit.command.subtitle)
                                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .caption))
                                .foregroundStyle(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.toggleFavorite(qualifiedId: hit.command.qualifiedId)
                    } label: {
                        Image(systemName: model.isFavorite(qualifiedId: hit.command.qualifiedId) ? "star.fill" : "star")
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Pin to favorites")
                }
                .padding(.vertical, 2)
                .background(idx == selection ? theme.accent.opacity(0.15) : Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if let status = model.statusMessage {
                PanelErrorBanner(message: status)
            }
        }
        .padding(JugnuTokens.Spacing.panelPadding)
        .frame(width: 560, height: 360)
        .background(theme.surface)
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
            guard displayed.indices.contains(selection) else { return .handled }
            onRun(displayed[selection].command)
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !displayed.isEmpty {
                selection = min(selection + 1, displayed.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
    }
}
