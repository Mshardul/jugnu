import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@MainActor
final class PalettePanelController {
    private let model: AppModel
    private var panel: KeyablePanel?
    private var hosting: NSHostingView<PaletteView>?

    init(model: AppModel) {
        self.model = model
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        hide()
        let view = PaletteView(
            model: model,
            onRun: { [weak self] cmd in
                Task { @MainActor in
                    await self?.model.run(cmd)
                    self?.hide()
                }
            },
            onClose: { [weak self] in self?.hide() },
            onOpenBrowseCatalog: { [weak self] in self?.model.openBrowseCatalog() }
        )
        let hosting = NSHostingView(rootView: view)
        self.hosting = hosting

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hosting
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel

        model.refreshIndex()
        let mouse = NSEvent.mouseLocation
        let frames = NSScreen.screens.map(\.frame)
        let screen: NSScreen
        if let idx = PalettePlacement.screenIndex(frames: frames, mouse: mouse),
           NSScreen.screens.indices.contains(idx) {
            screen = NSScreen.screens[idx]
        } else {
            screen = NSScreen.main ?? NSScreen.screens[0]
        }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + 40
        ))

        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduce ? 1 : 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(hosting)
        if !reduce {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }
}

struct PaletteView: View {
    @ObservedObject var model: AppModel
    var onRun: (IndexedCommand) -> Void
    var onClose: () -> Void
    var onOpenBrowseCatalog: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var hintIndex = 0
    @State private var bloom: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

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
        return "Try ‘\(hint)’…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title3))
                .padding(8)
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: query) { _, newValue in
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
            _ = model.search("")
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
        .onKeyPress(.escape) {
            onClose()
            return .handled
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
