import AppKit
import JugnuCore
import SwiftUI

@MainActor
public final class NotePanel: NSPanel {
    private let onSave: (String) -> Void
    private let onClose: () -> Void
    private let model: NoteModel

    public init(
        ui: UIDescriptor,
        persist: Bool,
        onSave: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onClose = onClose
        self.model = NoteModel(text: ui.content ?? "", persist: persist)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = ui.title ?? "Scratch"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        delegate = model
        model.onSave = { [weak self] text in self?.onSave(text) }
        model.onClose = { [weak self] in self?.onClose() }
        contentView = NSHostingView(rootView: NoteEditorView(model: model))
        center()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            onSave(model.text)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
private final class NoteModel: NSObject, ObservableObject, NSWindowDelegate {
    @Published var text: String
    let persist: Bool
    var onSave: ((String) -> Void)?
    var onClose: (() -> Void)?

    init(text: String, persist: Bool) {
        self.text = text
        self.persist = persist
    }

    func windowWillClose(_ notification: Notification) {
        if persist {
            onSave?(text)
        }
        onClose?()
    }
}

private struct NoteEditorView: View {
    @ObservedObject var model: NoteModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        TextEditor(text: $model.text)
            .font(JugnuTokens.font(presetId: store.presetId, role: .body))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(theme.surface)
            .foregroundStyle(theme.textPrimary)
    }
}
