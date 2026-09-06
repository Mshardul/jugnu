import AppKit
import JugnuCore
import SwiftUI

@MainActor
final class FirstRunSession: ObservableObject {
    @Published var page = 1
    @Published var keepAppCurrent = true
    @Published var keepAddonsCurrent = true
    @Published var useCommandSpace = false
    @Published var selectedIDs: Set<String> = []
    @Published var entries: [RegistryEntry] = []
    @Published var catalogMessage: String?

    func skipPage1InPlace() {
        keepAppCurrent = true
        keepAddonsCurrent = true
        useCommandSpace = false
        page = 2
    }

    func closeOutcome() -> (keepApp: Bool, keepAddons: Bool, cmdSpace: Bool, ids: [String]) {
        if page == 1 {
            return (true, true, false, [])
        }
        return (keepAppCurrent, keepAddonsCurrent, useCommandSpace, [])
    }
}

@MainActor
final class FirstRunWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let onDone: () -> Void
    private let session = FirstRunSession()
    private var window: NSWindow?
    private var finishing = false

    init(model: AppModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    func show() {
        let view = FirstRunView(
            session: session,
            model: model,
            onFinish: { [weak self] ids in
                self?.finish(
                    keepAppCurrent: self?.session.keepAppCurrent ?? true,
                    keepAddonsCurrent: self?.session.keepAddonsCurrent ?? true,
                    useCommandSpace: self?.session.useCommandSpace ?? false,
                    selectedAddonIDs: ids
                )
            }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Jugnu"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 640, height: 520))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if finishing { return true }
        let outcome = session.closeOutcome()
        finish(
            keepAppCurrent: outcome.keepApp,
            keepAddonsCurrent: outcome.keepAddons,
            useCommandSpace: outcome.cmdSpace,
            selectedAddonIDs: outcome.ids
        )
        return false
    }

    private func finish(
        keepAppCurrent: Bool,
        keepAddonsCurrent: Bool,
        useCommandSpace: Bool,
        selectedAddonIDs: [String]
    ) {
        guard !finishing else { return }
        finishing = true
        let roots = Self.localAddonRoots(for: selectedAddonIDs)
        Task { @MainActor in
            do {
                try await model.completeFirstRun(
                    keepAppCurrent: keepAppCurrent,
                    keepAddonsCurrent: keepAddonsCurrent,
                    useCommandSpace: useCommandSpace,
                    selectedAddonIDs: selectedAddonIDs,
                    localAddonRoots: roots
                )
            } catch {
                model.statusMessage = UserFacingError.message(for: error)
            }
            window?.delegate = nil
            window?.close()
            window = nil
            onDone()
        }
    }

    static func localAddonRoots(for ids: [String]) -> [URL] {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("addons"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("addons"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("addons"),
        ]
        var roots: [URL] = []
        for id in ids {
            for base in candidates {
                let root = base.appendingPathComponent(id)
                if FileManager.default.fileExists(atPath: root.appendingPathComponent("addon.yaml").path) {
                    roots.append(root)
                    break
                }
            }
        }
        return roots
    }
}

struct FirstRunView: View {
    @ObservedObject var session: FirstRunSession
    var model: AppModel
    var onFinish: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Jugnu").font(.largeTitle.weight(.semibold))
            if session.page == 1 {
                stepOne
            } else {
                stepTwo
            }
        }
        .padding(24)
        .frame(width: 640, height: 520)
        .task(id: session.page) {
            guard session.page == 2, session.entries.isEmpty else { return }
            await loadCatalog()
        }
    }

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A little light for everything on your Mac.")
                .foregroundStyle(.secondary)
            Toggle("Keep Jugnu current", isOn: $session.keepAppCurrent)
            Toggle("Keep addons current", isOn: $session.keepAddonsCurrent)
            Toggle("Use ⌘Space (replaces Spotlight — only if you opt in)", isOn: $session.useCommandSpace)
            if session.useCommandSpace {
                Text("Change Spotlight’s shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Button("Skip") {
                    session.skipPage1InPlace()
                }
                Spacer()
                Button("Continue") {
                    session.page = 2
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose addons to install")
                .font(.title2.weight(.semibold))
            if let catalogMessage = session.catalogMessage {
                Text(catalogMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(session.entries) { entry in
                        Toggle(isOn: binding(for: entry.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name).font(.headline)
                                if !entry.summary.isEmpty {
                                    Text(entry.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
            HStack {
                Button("Skip") {
                    onFinish([])
                }
                Spacer()
                Button("Continue") {
                    onFinish(Array(session.selectedIDs))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { session.selectedIDs.contains(id) },
            set: { on in
                if on {
                    session.selectedIDs.insert(id)
                } else {
                    session.selectedIDs.remove(id)
                }
            }
        )
    }

    private func loadCatalog() async {
        guard let url = URL(string: model.config.shell.registryURL) else {
            session.catalogMessage = "The catalog URL isn't valid."
            return
        }
        let result = await RegistryClient().fetchWithCache(from: url, cacheFile: model.paths.registryCacheFile)
        switch result {
        case .fresh(let fetched):
            session.entries = fetched
            session.catalogMessage = nil
        case .cached(let cached, let failure):
            session.entries = cached
            session.catalogMessage = UserFacingError.cachedCatalogMessage(for: failure)
        case .unavailable(let failure):
            session.catalogMessage = UserFacingError.message(for: failure)
        }
        let prechecked = FirstRunSelection.precheckedIDs(
            entries: session.entries,
            fallback: ShellConfig.recommendedAddonIDs
        )
        session.selectedIDs = Set(prechecked)
    }
}
