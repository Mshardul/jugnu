import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@MainActor
extension AppDelegate {
    func openAppShell(_ navigation: AppNavigation, on screen: NSScreen, model: AppModel) {
        guard let shellHost else { return }
        ensurePanelIfNeeded(model: model)
        shellHost.showAppShell(navigation)
        renderCurrentTop(model: model)
        shellHost.placeAppShellFrame(in: screen.visibleFrame)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in
            self?.dismissFromClickOutside()
        }
    }

    func openAppShellPage(_ page: AppShellPage) {
        guard let model, let shellHost else { return }
        var navigation = shellHost.appShellNavigation ?? .freshHome()
        navigation.page = page
        if page != .search {
            navigation.searchQuery = ""
        }
        if shellHost.isVisible, shellHost.stack.top.preset == .appShell {
            shellHost.updateAppShell(navigation)
            renderCurrentTop(model: model)
            return
        }
        guard let screen = screenUnderPointer() else { return }
        openAppShell(navigation, on: screen, model: model)
    }

    func handleAppShellControl(_ control: AppShellControl) {
        guard let model, let shellHost, let navigation = shellHost.appShellNavigation else { return }
        guard shellHost.stack.top.preset == .appShell else { return }
        switch applyAppShellControl(control, to: .visible(navigation)) {
        case .hidden:
            tearDownInFlight()
            shellHost.hide()
        case let .visible(next):
            guard next != navigation else { return }
            shellHost.updateAppShell(next)
            renderCurrentTop(model: model)
        }
    }

    func handlePanelEscape() {
        guard let shellHost else { return }
        if shellHost.stack.entries.last?.preset == .appShell {
            handleAppShellControl(.escape)
        } else {
            popOrDismiss()
        }
    }

    func handlePanelCommandW() {
        guard let shellHost else { return }
        if shellHost.stack.entries.last?.preset == .appShell {
            handleAppShellControl(.commandW)
        } else {
            popOrDismiss()
        }
    }

    func screenUnderPointer() -> NSScreen? {
        let frames = NSScreen.screens.map(\.frame)
        if let index = PalettePlacement.screenIndex(frames: frames, mouse: NSEvent.mouseLocation),
           NSScreen.screens.indices.contains(index)
        {
            return NSScreen.screens[index]
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    func renderAppShell(model: AppModel) {
        guard let shellHost, let navigation = shellHost.appShellNavigation else { return }
        appShellChrome.navigation = navigation
        appShellChrome.layout = loadHomeLayout(from: HomeLayoutStore(fileURL: model.paths.homeLayoutFile))
        appShellChrome.linesByDefinition = homeLines(model: model)
        appShellChrome.actions = searchActions(model: model)
        guard !shellHost.showsAppShellContent else { return }
        shellHost.installAppShellContent(AppShellView(
            chrome: appShellChrome,
            onPage: { [weak self] page in self?.openAppShellPage(page) },
            onDismiss: { [weak self] in self?.handleAppShellControl(.commandW) },
            onOpenSearch: { [weak self] in self?.openSearch(query: "") },
            onTypeToSearch: { [weak self] query in self?.openSearch(query: query) },
            onSearchBackdrop: { [weak self] in self?.handleAppShellControl(.searchBackdrop) },
            onRunAction: { [weak self] id in self?.runAppShellAction(qualifiedID: id) },
            onOpenDestination: { [weak self] page in self?.openAppShellPage(page) },
            pages: { [weak self] in
                if let self {
                    self.appShellPage(model: model, navigation: self.appShellChrome.navigation)
                }
            }
        ))
    }

    func openSearch(query: String) {
        guard let model, let shellHost else { return }
        var navigation = shellHost.appShellNavigation ?? .freshHome()
        navigation.page = .search
        navigation.searchQuery = query
        if shellHost.isVisible, shellHost.stack.top.preset == .appShell {
            shellHost.updateAppShell(navigation)
            renderCurrentTop(model: model)
            return
        }
        guard let screen = screenUnderPointer() else { return }
        openAppShell(navigation, on: screen, model: model)
    }

    func runAppShellAction(qualifiedID: String) {
        guard let model, let shellHost, var navigation = shellHost.appShellNavigation else { return }
        navigation.page = .home
        navigation.searchQuery = ""
        shellHost.updateAppShell(navigation)
        renderCurrentTop(model: model)
        guard let command = model.allCommands.first(where: { $0.qualifiedId == qualifiedID }) else { return }
        runCommand(command)
    }

    func homeLines(model: AppModel) -> [String: [String]] {
        let favorites = model.state.favoriteAddonIDs.map { model.addonDisplayName(id: $0) }
        let recent = model.state.recentCommandIDs.compactMap { id -> String? in
            guard let command = model.allCommands.first(where: { $0.qualifiedId == id }) else { return nil }
            return appShellSearchLabel(
                addonName: model.addonDisplayName(id: command.addonId),
                actionTitle: command.title
            )
        }
        return [
            BuiltInWidget.favoriteAddons: favorites,
            BuiltInWidget.recentActivity: recent
        ]
    }

    func searchActions(model: AppModel) -> [AppShellSearchAction] {
        model.allCommands.map { command in
            AppShellSearchAction(
                addonName: model.addonDisplayName(id: command.addonId),
                actionTitle: command.title,
                qualifiedID: command.qualifiedId
            )
        }
    }

    @ViewBuilder
    func appShellPage(model: AppModel, navigation: AppNavigation) -> some View {
        if navigation.page == .preferences {
            preferencesPage(model: model, navigation: navigation)
        } else if let detail = navigation.catalog.detail, navigation.page == .catalog {
            hostedAddonDetail(
                model: model,
                addonID: detail.addonID,
                tab: addonDetailTab(detail.section),
                onClose: { [weak self] in self?.handleAppShellControl(.escape) }
            )
        } else if navigation.page == .catalog {
            catalogPage(model: model, navigation: navigation)
        }
    }

    func updateAppNavigation(_ mutate: (inout AppNavigation) -> Void) {
        guard let shellHost, var navigation = shellHost.appShellNavigation else { return }
        mutate(&navigation)
        shellHost.updateAppShell(navigation)
        appShellChrome.navigation = navigation
    }

    func catalogPage(model: AppModel, navigation: AppNavigation) -> some View {
        let viewModel = catalogViewModel(model: model)
        return BrowseCatalogView(
            viewModel: viewModel,
            catalog: navigation.catalog,
            onCatalogChange: { [weak self] catalog in
                self?.updateAppNavigation { navigation in
                    let detail = navigation.catalog.detail
                    navigation.catalog = catalog
                    navigation.catalog.detail = detail
                }
            },
            onSelectCard: { [weak self] addonID in self?.pushDetail(addonID: addonID) },
            onOpenSettings: { [weak self] addonID in
                self?.pushDetail(addonID: addonID, tab: .settings)
            },
            onOpen: { [weak self] addonID in self?.runPrimary(addonID: addonID) }
        )
    }

    func preferencesPage(model: AppModel, navigation: AppNavigation) -> some View {
        PrefsView(
            themeConfig: Binding(
                get: { model.config.theme },
                set: { newTheme in
                    var config = model.config
                    config.theme = newTheme
                    try? model.saveConfig(config)
                }
            ),
            sound: Binding(
                get: { model.config.sound },
                set: { value in
                    var config = model.config
                    config.sound = value
                    try? model.saveConfig(config)
                }
            ),
            keepAppCurrent: Binding(
                get: { model.config.shell.keepAppCurrent },
                set: { value in
                    var config = model.config
                    config.shell.keepAppCurrent = value
                    try? model.saveConfig(config)
                }
            ),
            keepAddonsCurrent: Binding(
                get: { model.config.shell.keepAddonsCurrent },
                set: { value in
                    var config = model.config
                    config.shell.keepAddonsCurrent = value
                    try? model.saveConfig(config)
                }
            ),
            shellVersion: ShellVersion.current,
            registryURL: model.config.shell.registryURL,
            errorText: model.statusMessage,
            installedAddons: model.installedAddonIDs().map { id in
                (id: id, name: model.addonDisplayName(id: id), enabled: model.config.addons[id]?.enabled == true)
            },
            onCheckForUpdates: { [weak self] in
                Task { await self?.keepCurrent?.checkManual() }
            },
            onClose: { [weak self] in self?.handleAppShellControl(.commandW) },
            onApplyPreset: { preset in
                var config = model.config
                config.theme = preset
                try? model.saveConfig(config)
            },
            onSelectInstalled: { [weak self] id in
                self?.pushDetail(addonID: id, tab: .settings)
            },
            showsWindowHeader: false,
            section: navigation.preferencesSection,
            onSectionChange: { [weak self] section in
                self?.updateAppNavigation { navigation in
                    navigation.preferencesSection = section
                    navigation.page = .preferences
                }
            }
        )
    }

    @ViewBuilder
    func hostedAddonDetail(
        model: AppModel,
        addonID: String,
        tab: AddonDetailTab,
        onClose: @escaping () -> Void
    ) -> some View {
        let viewModel = catalogViewModel(model: model)
        if let entry = viewModel.entries.first(where: { $0.id == addonID }) {
            let configState = addonConfigState(for: addonID)
            AddonDetailView(
                entry: entry,
                isInstalled: viewModel.isInstalled(entry.id),
                isEnabled: viewModel.isEnabled(entry.id),
                isInstalling: viewModel.installingIDs.contains(entry.id),
                updateAvailable: viewModel.updateAvailable(entry.id),
                errorMessage: viewModel.errorMessage,
                initialTab: tab,
                permissionGrants: permissionGrants(for: entry),
                configSchema: configState.schema,
                configValues: configState.values,
                configError: configState.error,
                onInstall: { Task { await viewModel.install(entry) } },
                onUpdate: { Task { await viewModel.update(entry) } },
                onEnabledChange: { viewModel.setEnabled(entry.id, enabled: $0) },
                onUninstall: { viewModel.uninstall(id: entry.id, name: entry.name) },
                onRun: { [weak self] commandId in
                    self?.runDetailCommand(addonID: addonID, commandId: commandId)
                },
                onConfigChange: { [weak self] key, value in
                    self?.saveAddonConfigValue(addonID: addonID, key: key, value: value)
                },
                onOpenConfig: { [weak self] in
                    self?.openAddonConfigFile(addonID: addonID)
                },
                onResetConfig: { [weak self] in
                    self?.resetAddonConfigFile(addonID: addonID)
                    if let model = self?.model {
                        self?.renderCurrentTop(model: model)
                    }
                },
                onClose: onClose,
                onOpen: { [weak self] in self?.runPrimary(addonID: addonID) },
                isFavorite: viewModel.isFavoriteAddon(entry.id),
                onFavorite: { viewModel.toggleFavoriteAddon(entry.id) }
            )
        }
    }

    func permissionGrants(for entry: RegistryEntry) -> [AddonPermission: Bool] {
        var grants: [AddonPermission: Bool] = [:]
        for permission in entry.permissions where permission.isTCC {
            grants[permission] = TCCGrantStatus.isGranted(permission)
        }
        return grants
    }

    func addonDetailSection(_ tab: AddonDetailTab) -> AddonDetailSection {
        switch tab {
        case .overview: .overview
        case .commands: .actions
        case .widgets: .widgets
        case .settings: .settings
        }
    }

    func addonDetailTab(_ section: AddonDetailSection) -> AddonDetailTab {
        switch section {
        case .overview: .overview
        case .actions: .commands
        case .widgets: .widgets
        case .settings: .settings
        }
    }
}
