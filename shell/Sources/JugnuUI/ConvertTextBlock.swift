import AppKit
import JugnuCore
import SwiftUI

@MainActor
public final class ConvertTextBlockModel: ObservableObject {
    public typealias Converter = @Sendable (String, ConvertRoute) async throws -> String

    public static let debounce: Duration = .milliseconds(150)
    public static let liveInputLimit = 200_000

    @Published public var input = "" {
        didSet {
            if input != oldValue {
                replan()
            }
        }
    }

    @Published public var sourceOverride: String? {
        didSet {
            if sourceOverride != oldValue {
                replan()
            }
        }
    }

    @Published public var chosenTarget: String? {
        didSet {
            if chosenTarget != oldValue {
                replan()
            }
        }
    }

    @Published public var output = "" {
        didSet {
            if !applying, output != oldValue {
                outputEdited = true
            }
        }
    }

    @Published public var isReadOnly = true
    @Published public private(set) var plan: ConvertTextPlan
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var status: String?
    @Published public private(set) var isStale = false
    @Published public private(set) var isOverLiveLimit = false
    @Published public private(set) var outputEdited = false
    @Published public private(set) var pendingOutput: String?

    private let graph: ConvertGraph
    private let converter: Converter
    private let downloads: URL
    private let reveal: @MainActor (URL) -> Void
    private var task: Task<Void, Never>?
    private var applying = false
    private var lastGoodSource: String?

    public init(
        graph: ConvertGraph,
        downloads: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0],
        reveal: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) },
        converter: @escaping Converter
    ) {
        self.graph = graph
        self.downloads = downloads
        self.reveal = reveal
        self.converter = converter
        plan = ConvertTextPlan.make(text: "", sourceOverride: nil, chosenTarget: nil, graph: graph)
    }

    public var sourceChoices: [FormatDecl] {
        graph.sources(mode: .text)
    }

    public func label(for formatID: String) -> String {
        graph.format(id: formatID)?.label ?? formatID
    }

    private func replan() {
        plan = ConvertTextPlan.make(
            text: input,
            sourceOverride: sourceOverride,
            chosenTarget: chosenTarget,
            graph: graph
        )
        if plan.route == nil, sourceOverride == nil, let held = lastGoodSource, Self.looks(like: held, input) {
            var heldPlan = ConvertTextPlan.make(
                text: input,
                sourceOverride: held,
                chosenTarget: chosenTarget,
                graph: graph
            )
            heldPlan.detected = held
            plan = heldPlan
        }
        task?.cancel()
        status = nil
        guard let route = plan.route, !input.isEmpty else {
            if input.isEmpty {
                lastGoodSource = nil
            }
            isStale = false
            isOverLiveLimit = false
            errorMessage = nil
            apply("")
            return
        }
        isOverLiveLimit = input.utf8.count > Self.liveInputLimit
        if isOverLiveLimit {
            errorMessage = nil
            isStale = !output.isEmpty
            return
        }
        start(route: route, delay: Self.debounce)
    }

    private static func looks(like format: String, _ text: String) -> Bool {
        guard let first = text.first(where: { !$0.isWhitespace }) else { return false }
        switch format {
        case "json": return first == "{" || first == "["
        case "xml": return first == "<"
        default: return false
        }
    }

    public func convertNow() {
        guard let route = plan.route, !input.isEmpty else { return }
        task?.cancel()
        start(route: route, delay: .zero)
    }

    private func start(route: ConvertRoute, delay: Duration) {
        let text = input
        task = Task { [converter] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            do {
                let result = try await converter(text, route)
                guard !Task.isCancelled else { return }
                errorMessage = nil
                isStale = false
                lastGoodSource = route.from
                apply(result)
            } catch is CancellationError {
                return
            } catch let ConvertClientError.failed(message) {
                fail(message)
            } catch {
                fail("Conversion failed.")
            }
        }
    }

    private func fail(_ message: String) {
        guard !Task.isCancelled else { return }
        errorMessage = message
        isStale = !output.isEmpty
    }

    private func apply(_ text: String) {
        pendingOutput = nil
        if outputEdited, text != output {
            pendingOutput = text
            return
        }
        setOutput(text)
    }

    private func setOutput(_ text: String) {
        applying = true
        output = text
        applying = false
        outputEdited = false
        pendingOutput = nil
    }

    public func replaceEdits() {
        if let pending = pendingOutput {
            setOutput(pending)
        }
    }

    public func keepEdits() {
        pendingOutput = nil
    }

    public func copyOutput() {
        guard !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        status = "Copied"
    }

    public func downloadOutput() {
        guard !output.isEmpty, let target = plan.target else { return }
        let ext = graph.format(id: target)?.extensions.first ?? "txt"
        do {
            let url = try ConvertOutput.inDownloads(downloads, baseName: "converted", ext: ext)
            try output.write(to: url, atomically: true, encoding: .utf8)
            status = "Saved \(url.lastPathComponent) to Downloads"
            reveal(url)
        } catch {
            errorMessage = "Couldn't save the file."
        }
    }
}

public struct ConvertTextBlockView: View {
    @ObservedObject var model: ConvertTextBlockModel
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(model: ConvertTextBlockModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    private var palette: ShellPalette {
        ShellPalette(
            theme: JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme)),
            colorScheme: colorScheme
        )
    }

    public var body: some View {
        let colors = palette
        VStack(alignment: .leading, spacing: 12) {
            header(colors)
            HStack(spacing: 0) {
                inputPane(colors)
                Rectangle().fill(colors.border).frame(width: 1)
                outputPane(colors)
            }
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colors.border, lineWidth: 1))
            footer(colors)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(_ colors: ShellPalette) -> some View {
        HStack {
            Text("Convert text").font(.title3.weight(.semibold)).foregroundStyle(colors.text)
            Spacer()
            ShellIconButton(systemName: "xmark", label: "Close", palette: colors, action: onClose)
        }
    }

    private func inputPane(_ colors: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Input").font(.caption.weight(.semibold)).foregroundStyle(colors.muted)
                Spacer()
                Picker("Input format", selection: sourceBinding) {
                    Text("Auto (\(model.label(for: model.plan.detected)))").tag(String?.none)
                    ForEach(model.sourceChoices, id: \.id) { Text($0.label).tag(String?.some($0.id)) }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("Input format")
            }
            TextEditor(text: $model.input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .accessibilityLabel("Input text")
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func outputPane(_ colors: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Output").font(.caption.weight(.semibold)).foregroundStyle(colors.muted)
                Spacer()
                Picker("Output format", selection: targetBinding) {
                    ForEach(model.plan.targets, id: \.id) { Text($0.label).tag(String?.some($0.id)) }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(model.plan.targets.isEmpty)
                .accessibilityLabel("Output format")
                ShellIconButton(systemName: "doc.on.doc", label: "Copy", palette: colors, action: model.copyOutput)
                ShellIconButton(
                    systemName: "arrow.down.to.line",
                    label: "Download to a new file",
                    palette: colors,
                    action: model.downloadOutput
                )
                ShellIconButton(
                    systemName: model.isReadOnly ? "lock.fill" : "lock.open",
                    label: model.isReadOnly ? "Read-only (click to edit)" : "Editable (click to lock)",
                    active: model.isReadOnly,
                    palette: colors
                ) { model.isReadOnly.toggle() }
            }
            if model.isReadOnly {
                ScrollView {
                    Text(model.output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .foregroundStyle(colors.text)
                        .opacity(model.isStale ? 0.45 : 1)
                }
            } else {
                TextEditor(text: $model.output)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .opacity(model.isStale ? 0.45 : 1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footer(_ colors: ShellPalette) -> some View {
        let message = footerMessage
        return HStack(spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundStyle(model.errorMessage == nil ? colors.muted : Color.red)
                .accessibilityLabel(message)
            if model.pendingOutput != nil {
                Button("Replace", action: model.replaceEdits)
                Button("Keep my edits", action: model.keepEdits)
            } else if model.isOverLiveLimit {
                Button("Convert", action: model.convertNow)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerMessage: String {
        if model.pendingOutput != nil {
            return "Replace your edits with the new conversion?"
        }
        if model.isOverLiveLimit {
            return "Large input: live conversion is off. Press Convert."
        }
        return model.errorMessage ?? model.status ?? emptyHint
    }

    private var emptyHint: String {
        if model.input.isEmpty {
            return "Paste or type text to convert."
        }
        if model.plan.targets.isEmpty {
            return "Nothing converts from \(model.label(for: model.plan.source)). Try changing the input format."
        }
        return ""
    }

    private var sourceBinding: Binding<String?> {
        Binding(get: { model.sourceOverride }, set: { model.sourceOverride = $0 })
    }

    private var targetBinding: Binding<String?> {
        Binding(get: { model.plan.target }, set: { model.chosenTarget = $0 })
    }
}
