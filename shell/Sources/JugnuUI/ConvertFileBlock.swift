import AppKit
import JugnuCore
import SwiftUI
import UniformTypeIdentifiers

public struct ConvertFileResult: Identifiable, Equatable {
    public enum Outcome: Equatable {
        case saved(URL)
        case failed(String)
    }

    public let id = UUID()
    public var name: String
    public var outcome: Outcome
}

@MainActor
public final class ConvertFileBlockModel: ObservableObject {
    public typealias Converter = @Sendable (URL, ConvertRoute, String) async throws -> URL

    @Published public private(set) var plan: ConvertFilePlan
    @Published public private(set) var results: [ConvertFileResult] = []
    @Published public private(set) var isConverting = false
    @Published public var chosenTarget: String? {
        didSet {
            if chosenTarget != oldValue {
                replan()
            }
        }
    }

    private let graph: ConvertGraph
    private let converter: Converter
    private var files: [URL] = []

    public init(graph: ConvertGraph, files: [URL] = [], converter: @escaping Converter) {
        self.graph = graph
        self.converter = converter
        self.files = files
        plan = ConvertFilePlan.make(files: files, chosenTarget: nil, graph: graph)
    }

    public func label(for formatID: String) -> String {
        graph.format(id: formatID)?.label ?? formatID
    }

    public var canConvert: Bool {
        plan.route != nil && !isConverting
    }

    public static let stagingRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("jugnu-convert-clipboard", isDirectory: true)

    public static func isStaged(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(stagingRoot.standardizedFileURL.path + "/")
    }

    public func setFiles(_ urls: [URL]) {
        removeStaged(files.filter { Self.isStaged($0) && !urls.contains($0) })
        files = urls
        results = []
        replan()
    }

    public func addFiles(_ urls: [URL]) {
        setFiles(files + urls.filter { !files.contains($0) })
    }

    public func pasteFromClipboard(pasteboard: NSPasteboard = .general) {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        if !urls.isEmpty {
            setFiles(urls)
        } else if let staged = Self.stageImage(from: pasteboard) {
            setFiles([staged])
        }
    }

    static func stageImage(from pasteboard: NSPasteboard) -> URL? {
        let tiffAsPNG = pasteboard.data(forType: .tiff)
            .flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }
        guard let png = pasteboard.data(forType: .png) ?? tiffAsPNG else { return nil }
        let dir = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = dir.appendingPathComponent("Clipboard image.png")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            try? FileManager.default.removeItem(at: dir)
            return nil
        }
    }

    private func removeStaged(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    private func replan() {
        plan = ConvertFilePlan.make(files: files, chosenTarget: chosenTarget, graph: graph)
    }

    public func convert() async {
        guard let route = plan.route, let target = plan.target, !isConverting else { return }
        let ext = graph.format(id: target)?.extensions.first ?? target
        isConverting = true
        results = []
        for file in plan.files {
            do {
                let out = try await converter(file, route, ext)
                results.append(ConvertFileResult(name: file.lastPathComponent, outcome: .saved(out)))
            } catch let ConvertClientError.failed(message) {
                results.append(ConvertFileResult(name: file.lastPathComponent, outcome: .failed(message)))
            } catch {
                results.append(ConvertFileResult(name: file.lastPathComponent, outcome: .failed("Conversion failed.")))
            }
        }
        isConverting = false
        let staged = files.filter { Self.isStaged($0) }
        if !staged.isEmpty {
            removeStaged(staged)
            files.removeAll { Self.isStaged($0) }
            replan()
        }
    }

    public func message(for problem: ConvertFilePlan.Problem) -> String {
        switch problem {
        case .noFiles:
            "Drop a file here, choose one, or paste one you copied."
        case let .unrecognized(url):
            "Can't tell what \(url.lastPathComponent) is."
        case .mixedFormats:
            "These files are different formats. Convert one kind at a time."
        case let .noConversions(format):
            "Nothing converts from \(label(for: format)) yet."
        }
    }
}

public struct ConvertFileBlockView: View {
    @ObservedObject var model: ConvertFileBlockModel
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared
    @State private var dropTargeted = false

    public init(model: ConvertFileBlockModel, onClose: @escaping () -> Void) {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Convert a file").font(.title3.weight(.semibold)).foregroundStyle(colors.text)
                Spacer()
                ShellIconButton(systemName: "xmark", label: "Close", palette: colors, action: onClose)
            }
            dropZone(colors)
            controls(colors)
            resultRows(colors)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity)
    }

    private func dropZone(_ colors: ShellPalette) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 22)).foregroundStyle(colors.muted)
            Text(summary).foregroundStyle(colors.text).multilineTextAlignment(.center)
            HStack {
                Button("Choose file…", action: chooseFiles)
                Button("Paste from clipboard") { model.pasteFromClipboard() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .background(dropTargeted ? colors.accentSoft : colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(dropTargeted ? colors.accent : colors.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
        .accessibilityElement(children: .contain)
    }

    private var summary: String {
        if let problem = model.plan.problem {
            return model.message(for: problem)
        }
        let count = model.plan.files.count
        let kind = model.plan.source.map { model.label(for: $0) } ?? ""
        return count == 1 ? "\(model.plan.files[0].lastPathComponent) · \(kind)" : "\(count) files · \(kind)"
    }

    private func controls(_ colors: ShellPalette) -> some View {
        HStack {
            Text("Output").font(.caption.weight(.semibold)).foregroundStyle(colors.muted)
            Picker("Output format", selection: targetBinding) {
                ForEach(model.plan.targets, id: \.id) { Text($0.label).tag(String?.some($0.id)) }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(model.plan.targets.isEmpty)
            .accessibilityLabel("Output format")
            Spacer()
            Button(model.isConverting ? "Converting…" : "Convert") { Task { await model.convert() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canConvert)
        }
    }

    private func resultRows(_ colors: ShellPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.results) { result in
                HStack {
                    switch result.outcome {
                    case let .saved(url):
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(colors.status)
                        Text(url.lastPathComponent).foregroundStyle(colors.text)
                        Spacer()
                        ShellIconButton(systemName: "magnifyingglass", label: "Reveal in Finder", palette: colors) {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        ShellIconButton(systemName: "doc.on.doc", label: "Copy path", palette: colors) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        }
                    case let .failed(message):
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.red)
                        Text("\(result.name): \(message)").foregroundStyle(Color.red)
                        Spacer()
                    }
                }
            }
        }
    }

    private var targetBinding: Binding<String?> {
        Binding(get: { model.plan.target }, set: { model.chosenTarget = $0 })
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            model.setFiles(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let accepted = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !accepted.isEmpty else { return false }
        Task { @MainActor in
            var urls: [URL] = []
            for provider in accepted {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                   let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil)
                {
                    urls.append(url)
                }
            }
            if !urls.isEmpty {
                model.setFiles(urls)
            }
        }
        return true
    }
}
