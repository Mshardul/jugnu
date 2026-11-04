import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@MainActor
extension AppDelegate {
    func openHostedBlock(_ block: HostedBlock) {
        guard let model, let shellHost else { return }
        if block == .convertText, convertTextModel == nil || shellHost.appShellNavigation?.block != .convertText {
            convertTextModel = makeConvertTextModel(model: model)
        }
        if block == .convertFile, convertFileModel == nil || shellHost.appShellNavigation?.block != .convertFile {
            convertFileModel = makeConvertFileModel(model: model)
        }
        if shellHost.isVisible, shellHost.stack.top.preset == .appShell {
            let navigation = (shellHost.appShellNavigation ?? .freshHome()).openingBlock(block)
            shellHost.updateAppShell(navigation)
            renderCurrentTop(model: model)
            return
        }
        guard let screen = screenUnderPointer() else { return }
        openAppShell(AppNavigation.freshHome().openingBlock(block), on: screen, model: model)
    }
}

@MainActor
extension AppDelegate {
    func convertSources(model: AppModel) -> [(manifest: AddonManifest, root: URL)] {
        var seen = Set<String>()
        var out: [(AddonManifest, URL)] = []
        for command in model.allCommands where seen.insert(command.addonId).inserted {
            guard let manifest = try? ManifestLoader.load(from: command.addonRoot),
                  !manifest.converters.isEmpty || !manifest.formats.isEmpty
            else { continue }
            out.append((manifest, command.addonRoot))
        }
        return out
    }

    func makeConvertFileModel(model: AppModel) -> ConvertFileBlockModel {
        let sources = convertSources(model: model)
        let graph = ConvertGraph(manifests: sources.map(\.manifest))
        let client = ConvertClient(paths: model.paths, timeout: 30)
        let byAddon = Dictionary(sources.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let fileModel = ConvertFileBlockModel(graph: graph) { input, route, ext in
            guard let source = byAddon[route.addonID] else {
                throw ConvertClientError.failed("That converter isn't available.")
            }
            return try await client.convertFile(
                input,
                outputExtension: ext,
                outputDirectory: ConvertFileBlockModel.isStaged(input) ? downloads : nil,
                route: route,
                manifest: source.manifest,
                addonRoot: source.root
            )
        }
        fileModel.pasteFromClipboard()
        return fileModel
    }

    func makeConvertTextModel(model: AppModel) -> ConvertTextBlockModel {
        let sources = convertSources(model: model)
        let graph = ConvertGraph(manifests: sources.map(\.manifest))
        let client = ConvertClient(paths: model.paths)
        let byAddon = Dictionary(sources.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
        let textModel = ConvertTextBlockModel(graph: graph) { text, route in
            guard let source = byAddon[route.addonID] else {
                throw ConvertClientError.failed("That converter isn't available.")
            }
            return try await client.convertText(text, route: route, manifest: source.manifest, addonRoot: source.root)
        }
        textModel.input = NSPasteboard.general.string(forType: .string) ?? ""
        return textModel
    }

    @ViewBuilder
    func hostedBlockPage(model _: AppModel, block: HostedBlock) -> some View {
        switch block {
        case .convertText:
            if let textModel = convertTextModel {
                ConvertTextBlockView(model: textModel) { [weak self] in self?.handleAppShellControl(.escape) }
            }
        case .convertFile:
            if let fileModel = convertFileModel {
                ConvertFileBlockView(model: fileModel) { [weak self] in self?.handleAppShellControl(.escape) }
            }
        }
    }
}
