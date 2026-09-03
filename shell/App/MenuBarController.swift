import AppKit

struct RecoveryMenuActions {
    var onResetConfig: () -> Void
    var onOpenConfig: () -> Void
    var onDisableAllAddons: () -> Void
    var onTryAgain: () -> Void
}

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let proxy: Proxy
    private let recoveryProxy: RecoveryProxy?

    init(
        onOpenPalette: @escaping () -> Void,
        onPreferences: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        recovery: RecoveryMenuActions? = nil
    ) {
        proxy = Proxy(onOpenPalette: onOpenPalette, onPreferences: onPreferences, onQuit: onQuit)
        recoveryProxy = recovery.map { RecoveryProxy(actions: $0) }
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
        if let recoveryProxy {
            menu.addItem(Self.named(RecoveryMenuCopy.resetConfig, #selector(RecoveryProxy.resetConfig), recoveryProxy))
            menu.addItem(Self.named(RecoveryMenuCopy.openConfig, #selector(RecoveryProxy.openConfig), recoveryProxy))
            menu.addItem(Self.named(RecoveryMenuCopy.disableAddons, #selector(RecoveryProxy.disableAddons), recoveryProxy))
            menu.addItem(Self.named(RecoveryMenuCopy.tryAgain, #selector(RecoveryProxy.tryAgain), recoveryProxy))
            menu.addItem(.separator())
        } else {
            let open = NSMenuItem(title: "Open Palette", action: #selector(Proxy.openPalette), keyEquivalent: "")
            open.target = proxy
            let prefs = NSMenuItem(title: "Preferences…", action: #selector(Proxy.preferences), keyEquivalent: ",")
            prefs.target = proxy
            menu.addItem(open)
            menu.addItem(prefs)
            menu.addItem(.separator())
        }
        let quit = NSMenuItem(title: "Quit Jugnu", action: #selector(Proxy.quit), keyEquivalent: "q")
        quit.target = proxy
        menu.addItem(quit)
        statusItem.menu = menu
    }

    var menuItemTitles: [String] {
        statusItem.menu?.items.compactMap { $0.isSeparatorItem ? nil : $0.title } ?? []
    }

    private static func named(_ title: String, _ sel: Selector, _ target: RecoveryProxy) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = target
        return item
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

@MainActor
private final class RecoveryProxy: NSObject {
    let actions: RecoveryMenuActions

    init(actions: RecoveryMenuActions) {
        self.actions = actions
    }

    @objc func resetConfig() { actions.onResetConfig() }
    @objc func openConfig() { actions.onOpenConfig() }
    @objc func disableAddons() { actions.onDisableAllAddons() }
    @objc func tryAgain() { actions.onTryAgain() }
}
