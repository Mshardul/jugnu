import AppKit
import JugnuCore
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PalettePanelController {
    private let model: AppModel
    private var panel: NSPanel?
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
        if panel == nil {
            let view = PaletteView(
                model: model,
                onRun: { [weak self] cmd in
                    Task { @MainActor in
                        await self?.model.run(cmd)
                        self?.hide()
                    }
                },
                onClose: { [weak self] in self?.hide() }
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
        }

        model.refreshIndex()
        guard let panel else { return }
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2 + 40
            )
            panel.setFrameOrigin(origin)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(hosting)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

struct PaletteView: View {
    @ObservedObject var model: AppModel
    var onRun: (IndexedCommand) -> Void
    var onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search commands", text: $query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: query) { _, newValue in
                    _ = model.search(newValue)
                    selection = 0
                }
                .onAppear {
                    _ = model.search("")
                }

            List(Array(model.results.enumerated()), id: \.element.qualifiedId) { idx, cmd in
                Button {
                    onRun(cmd)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cmd.title).font(.headline)
                        if !cmd.subtitle.isEmpty {
                            Text(cmd.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .background(idx == selection ? Color.accentColor.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)

            if let status = model.statusMessage {
                Text(status).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 560, height: 360)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.2)))
        .focusable()
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.return) {
            guard model.results.indices.contains(selection) else { return .handled }
            onRun(model.results[selection])
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !model.results.isEmpty {
                selection = min(selection + 1, model.results.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
    }
}
