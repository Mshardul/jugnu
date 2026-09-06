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
        onCheckForUpdates: (() -> Void)? = nil,
        recovery: RecoveryMenuActions? = nil
    ) {
        proxy = Proxy(
            onOpenPalette: onOpenPalette,
            onPreferences: onPreferences,
            onQuit: onQuit,
            onCheckForUpdates: onCheckForUpdates
        )
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
            if onCheckForUpdates != nil {
                let updates = NSMenuItem(
                    title: "Check for Updates…",
                    action: #selector(Proxy.checkForUpdates),
                    keyEquivalent: ""
                )
                updates.target = proxy
                menu.addItem(updates)
            }
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
    let onCheckForUpdates: (() -> Void)?

    init(
        onOpenPalette: @escaping () -> Void,
        onPreferences: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onCheckForUpdates: (() -> Void)?
    ) {
        self.onOpenPalette = onOpenPalette
        self.onPreferences = onPreferences
        self.onQuit = onQuit
        self.onCheckForUpdates = onCheckForUpdates
    }

    @objc func openPalette() { onOpenPalette() }
    @objc func preferences() { onPreferences() }
    @objc func quit() { onQuit() }
    @objc func checkForUpdates() { onCheckForUpdates?() }
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
