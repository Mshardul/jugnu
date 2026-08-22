import AppKit
import JugnuCore
import SwiftUI

@MainActor
public final class FormPanel: KeyablePanel {
    private let errorState = PanelErrorState()
    private let onCancel: () -> Void

    public init(
        ui: UIDescriptor,
        onSubmit: @escaping ([String: JSONValue]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        contentView = NSHostingView(
            rootView: ThemedPanelBackground {
                FormPanelView(ui: ui, errorState: errorState, onSubmit: onSubmit, onCancel: onCancel)
            }
        )
        center()
    }

    public func presentError(_ message: String) {
        errorState.message = message
    }

    override public func cancelOperation(_ sender: Any?) { onCancel() }
}

private struct FormPanelView: View {
    let ui: UIDescriptor
    @ObservedObject var errorState: PanelErrorState
    var onSubmit: ([String: JSONValue]) -> Void
    var onCancel: () -> Void

    @State private var textValues: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    private var fields: [UIFormField] { ui.fields ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Text(ui.title ?? "Form")
                .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
            ForEach(fields, id: \.id) { field in
                Text(field.label)
                    .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                    .foregroundStyle(theme.textSecondary)
                if field.kind == "toggle" {
                    Toggle("", isOn: boolBinding(field))
                        .labelsHidden()
                } else {
                    TextField(field.label, text: textBinding(field))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            if let message = errorState.message {
                PanelErrorBanner(message: message)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Submit", action: submit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear(perform: seed)
    }

    private func seed() {
        for field in fields {
            switch field.value {
            case .bool(let value):
                boolValues[field.id] = value
            case .string(let value):
                textValues[field.id] = value
            case .number(let value):
                textValues[field.id] = String(value)
            default:
                textValues[field.id] = textValues[field.id] ?? ""
            }
        }
    }

    private func textBinding(_ field: UIFormField) -> Binding<String> {
        Binding(
            get: { textValues[field.id] ?? "" },
            set: { textValues[field.id] = $0 }
        )
    }

    private func boolBinding(_ field: UIFormField) -> Binding<Bool> {
        Binding(
            get: { boolValues[field.id] ?? false },
            set: { boolValues[field.id] = $0 }
        )
    }

    private func submit() {
        var values: [String: JSONValue] = [:]
        for field in fields {
            if field.kind == "toggle" {
                values[field.id] = .bool(boolValues[field.id] ?? false)
            } else {
                values[field.id] = .string(textValues[field.id] ?? "")
            }
        }
        onSubmit(values)
    }
}
