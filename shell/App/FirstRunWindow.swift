import AppKit
import JugnuCore
import SwiftUI

@MainActor
final class FirstRunWindowController {
    private let model: AppModel
    private let onDone: () -> Void
    private var window: NSWindow?

    init(model: AppModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    func show() {
        let view = FirstRunView(
            onContinue: { [weak self] install, useCmdSpace in
                self?.finish(installRecommended: install, useCommandSpace: useCmdSpace)
            }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Jugnu"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 320))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func finish(installRecommended: Bool, useCommandSpace: Bool) {
        let roots = Self.recommendedLocalRoots()
        Task { @MainActor in
            do {
                try await model.completeFirstRun(
                    installRecommended: installRecommended,
                    useCommandSpace: useCommandSpace,
                    localAddonRoots: roots
                )
            } catch {
                model.statusMessage = String(describing: error)
            }
            window?.close()
            window = nil
            onDone()
        }
    }

    static func recommendedLocalRoots() -> [URL] {
        let ids = ["mic-mute", "focus-toggle", "paste-plain"]
        var roots: [URL] = []
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("addons"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("addons"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("addons"),
        ]
        for base in candidates {
            for id in ids {
                let root = base.appendingPathComponent(id)
                if FileManager.default.fileExists(atPath: root.appendingPathComponent("addon.yaml").path) {
                    roots.append(root)
                }
            }
            if roots.count == ids.count { break }
            roots.removeAll()
        }
        return roots
    }
}

struct FirstRunView: View {
    var onContinue: (_ installRecommended: Bool, _ useCommandSpace: Bool) -> Void

    @State private var installRecommended = true
    @State private var useCommandSpace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Jugnu").font(.largeTitle.weight(.semibold))
            Text("A light command palette for macOS addons.")
                .foregroundStyle(.secondary)

            Toggle("Install recommended addons (mic mute, focus, paste plain)", isOn: $installRecommended)
            Toggle("Use ⌘Space (replaces Spotlight — only if you opt in)", isOn: $useCommandSpace)

            if useCommandSpace {
                Text("You’ll need to change Spotlight’s shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue(installRecommended, useCommandSpace)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 320)
    }
}
