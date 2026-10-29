import AppKit
import JugnuCore
@testable import JugnuUI
import SwiftUI
import XCTest

@MainActor
final class AppShellSnapshotTests: XCTestCase {
    private let directory = URL(fileURLWithPath: "/tmp/jugnu-shots", isDirectory: true)

    func testRenderAppShellSurfaces() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = SnapshotCatalogModel()

        let home = AppShellChromeModel()
        home.layout = defaultHomeLayout()
        home.linesByDefinition = [
            BuiltInWidget.favoriteAddons: ["Audio", "Floating Note"],
            BuiltInWidget.recentActivity: ["Audio › Mute microphone", "Ports › Free a port"]
        ]
        try write(shell(home) { EmptyView() }, "home")

        let catalog = AppShellChromeModel()
        catalog.navigation.page = .catalog
        try write(shell(catalog) {
            BrowseCatalogView(viewModel: model, onSelectCard: { _ in })
        }, "catalog")

        let prefs = AppShellChromeModel()
        prefs.navigation.page = .preferences
        try write(shell(prefs) { PrefsView(
            themeConfig: .constant(.firefly),
            sound: .constant(true),
            keepAppCurrent: .constant(true),
            keepAddonsCurrent: .constant(true),
            shellVersion: "0.1.0",
            registryURL: ShellConfig.defaultRegistryURL,
            installedAddons: [("jugnu.audio-toggles", "Audio", true), ("jugnu.floating-note", "Floating Note", true)],
            onCheckForUpdates: {},
            onClose: {},
            onApplyPreset: { _ in },
            showsWindowHeader: false
        ) }, "preferences")

        try write(shell(prefs) { PrefsView(
            themeConfig: .constant(.firefly),
            sound: .constant(true),
            keepAppCurrent: .constant(true),
            keepAddonsCurrent: .constant(true),
            shellVersion: "0.1.0",
            registryURL: ShellConfig.defaultRegistryURL,
            installedAddons: [("jugnu.audio-toggles", "Audio", true), ("jugnu.floating-note", "Floating Note", false)],
            onCheckForUpdates: {},
            onClose: {},
            onApplyPreset: { _ in },
            showsWindowHeader: false,
            section: .installed
        ) }, "preferences-installed")

        try write(shell(prefs) { PrefsView(
            themeConfig: .constant(.firefly),
            sound: .constant(true),
            keepAppCurrent: .constant(true),
            keepAddonsCurrent: .constant(true),
            shellVersion: "0.1.0",
            registryURL: ShellConfig.defaultRegistryURL,
            installedAddons: [],
            onCheckForUpdates: {},
            onClose: {},
            onApplyPreset: { _ in },
            showsWindowHeader: false,
            section: .updates
        ) }, "preferences-updates")

        try write(shell(prefs) { PrefsView(
            themeConfig: .constant(.firefly),
            sound: .constant(true),
            keepAppCurrent: .constant(true),
            keepAddonsCurrent: .constant(true),
            shellVersion: "0.1.0",
            registryURL: ShellConfig.defaultRegistryURL,
            onCheckForUpdates: {},
            onClose: {},
            onApplyPreset: { _ in },
            showsWindowHeader: false,
            section: .general
        ) }, "preferences-general")

        let detail = AppShellChromeModel()
        detail.navigation.page = .catalog
        try write(shell(detail) { AddonDetailView(
            entry: model.entries[0],
            isInstalled: true,
            isEnabled: true,
            isInstalling: false,
            updateAvailable: false,
            onInstall: {},
            onEnabledChange: { _ in },
            onUninstall: {},
            onClose: {}
        ) }, "detail")

        let search = AppShellChromeModel()
        search.navigation.page = .search
        search.navigation.searchQuery = "audio"
        search.actions = [
            AppShellSearchAction(
                addonName: "Audio",
                actionTitle: "Mute microphone",
                qualifiedID: "jugnu.audio-toggles.mute"
            )
        ]
        try write(shell(search) { EmptyView() }, "search")
    }

    private func shell(_ chrome: AppShellChromeModel, @ViewBuilder pages: @escaping () -> some View) -> some View {
        AppShellView(
            chrome: chrome,
            onPage: { _ in },
            onDismiss: {},
            onOpenSearch: {},
            onTypeToSearch: { _ in },
            onSearchBackdrop: {},
            onRunAction: { _ in },
            onOpenDestination: { _ in },
            pages: pages
        )
        .environment(\.colorScheme, .dark)
        .frame(width: 1376, height: 715)
    }

    private func write(_ view: some View, _ name: String) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 1376, height: 715)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.setFrame(NSRect(x: -4000, y: -4000, width: 1376, height: 715), display: true)
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            XCTFail("no bitmap \(name)")
            return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("no png \(name)")
            return
        }
        let url = directory.appendingPathComponent("\(name).png")
        try png.write(to: url)
        XCTAssertGreaterThan(png.count, 10000, name)
    }
}

@MainActor
private final class SnapshotCatalogModel: ObservableObject, BrowseCatalogViewModelProtocol {
    var entries: [RegistryEntry]
    var selection: CatalogSidebarSelection = .all
    var selectedTags: Set<String> = []
    var searchText = ""
    var staleMessage: String?
    var errorMessage: String?
    var installingIDs: Set<String> = []
    let categories = CatalogTaxonomy.categories
    var recentAddonIDs: [String] = ["jugnu.audio-toggles"]
    private let installed: Set<String> = ["jugnu.audio-toggles", "jugnu.floating-note"]
    private let favorites: Set<String> = ["jugnu.audio-toggles"]

    init() {
        entries = [
            Self.entry(
                "jugnu.audio-toggles",
                "Audio",
                "System",
                "Audio",
                "Microphone and output controls with compact live widgets.",
                2,
                "mute",
                [.microphone]
            ),
            Self.entry(
                "jugnu.focus-toggle",
                "Intervals",
                "Focus",
                "Focus",
                "Run focus cycles and scheduled nudges from one place.",
                3,
                "start"
            ),
            Self.entry(
                "jugnu.floating-note",
                "Floating Note",
                "Notes",
                "Notes",
                "Keep a lightweight note above whatever you are doing.",
                1,
                nil
            ),
            Self.entry(
                "jugnu.ports",
                "Ports",
                "System",
                "Developer",
                "Find listening processes and stop the one holding a port.",
                1,
                nil,
                [.network]
            ),
            Self.entry(
                "jugnu.clip-tools",
                "Clipboard",
                "Clipboard",
                nil,
                "Keep recent clippings and paste one back.",
                2,
                "paste",
                [.clipboard]
            )
        ]
    }

    var filtered: [RegistryEntry] {
        entries
    }

    func isInstalled(_ id: String) -> Bool {
        installed.contains(id)
    }

    func isEnabled(_ id: String) -> Bool {
        installed.contains(id)
    }

    func updateAvailable(_ id: String) -> Bool {
        id == "jugnu.focus-toggle"
    }

    func isFavoriteAddon(_ id: String) -> Bool {
        favorites.contains(id)
    }

    func toggleFavoriteAddon(_: String) {}
    func load() async {}
    func install(_: RegistryEntry) async {}
    func update(_: RegistryEntry) async {}
    func setEnabled(_: String, enabled _: Bool) {}
    func uninstall(id _: String, name _: String) {}

    private static func entry(
        _ id: String,
        _ name: String,
        _ category: String,
        _ subcategory: String?,
        _ summary: String,
        _ commands: Int,
        _ primary: String?,
        _ permissions: [AddonPermission] = []
    ) -> RegistryEntry {
        RegistryEntry(
            id: id,
            name: name,
            version: "1.2.0",
            api: 1,
            url: "https://example.com/\(id).zip",
            sha256: String(repeating: "a", count: 64),
            summary: summary,
            category: category,
            subcategory: subcategory,
            commands: (0 ..< commands).map {
                RegistryCommand(id: "c\($0)", title: "Action \($0 + 1)", subtitle: "Does one thing.")
            },
            permissions: permissions,
            primary: primary
        )
    }
}
