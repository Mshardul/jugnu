import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@main
struct JugnuMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var model: AppModel?
    private var palette: PalettePanelController?
    private var hotkey: HotkeyController?
    private var firstRun: FirstRunWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model
        model.bootstrap()

        let palette = PalettePanelController(model: model)
        self.palette = palette

        let menuBar = MenuBarController(
            onOpenPalette: { [weak palette] in palette?.toggle() },
            onPreferences: { [weak self] in self?.showPrefs() },
            onQuit: { NSApp.terminate(nil) }
        )
        self.menuBar = menuBar

        let hotkey = HotkeyController(model: model) { [weak palette] in
            palette?.toggle()
        }
        self.hotkey = hotkey
        hotkey.registerFromConfig()

        if !model.state.firstRunCompleted {
            let first = FirstRunWindowController(model: model) { [weak self, weak hotkey] in
                hotkey?.registerFromConfig()
                self?.firstRun = nil
            }
            self.firstRun = first
            first.show()
        }
    }

    private func showPrefs() {
        guard let model else { return }
        let view = PrefsView(model: model)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Jugnu Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 560))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
