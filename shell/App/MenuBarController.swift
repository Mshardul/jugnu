import AppKit

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let proxy: Proxy

    init(onOpenPalette: @escaping () -> Void, onPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
        proxy = Proxy(onOpenPalette: onOpenPalette, onPreferences: onPreferences, onQuit: onQuit)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Jugnu"
            }
            button.toolTip = "Jugnu"
        }

        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Palette", action: #selector(Proxy.openPalette), keyEquivalent: "")
        open.target = proxy
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(Proxy.preferences), keyEquivalent: ",")
        prefs.target = proxy
        let quit = NSMenuItem(title: "Quit Jugnu", action: #selector(Proxy.quit), keyEquivalent: "q")
        quit.target = proxy
        menu.addItem(open)
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(quit)
        statusItem.menu = menu
    }
}

@MainActor
private final class Proxy: NSObject {
    let onOpenPalette: () -> Void
    let onPreferences: () -> Void
    let onQuit: () -> Void

    init(onOpenPalette: @escaping () -> Void, onPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenPalette = onOpenPalette
        self.onPreferences = onPreferences
        self.onQuit = onQuit
    }

    @objc func openPalette() { onOpenPalette() }
    @objc func preferences() { onPreferences() }
    @objc func quit() { onQuit() }
}
