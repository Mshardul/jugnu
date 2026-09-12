import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@MainActor
extension AppDelegate {
    func pushSettings() {
        guard let model, let shellHost else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        syncCatalogSnapshot()
        ensurePanelIfNeeded(model: model)
        let entry = ShellStackEntry(.settings(scroll: 0, focusedControlID: nil))
        if shellHost.stack.top.preset == .catalog {
            shellHost.replace(entry)
        } else {
            shellHost.push(entry)
        }
        renderCurrentTop(model: model)
        shellHost.morphFrame(to: .settings, compactLauncher: false, on: screen)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
    }

    func pushCatalog() {
        guard let model, let shellHost else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        ensurePanelIfNeeded(model: model)
        let entry = ShellStackEntry(.catalog(
            category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil
        ))
        if shellHost.stack.top.preset == .settings {
            shellHost.replace(entry)
        } else {
            shellHost.push(entry)
        }
        renderCurrentTop(model: model)
        shellHost.morphFrame(to: .catalog, compactLauncher: false, on: screen)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
    }

    func pushDetail(addonID: String, tab: AddonDetailTab = .overview) {
        guard let model, let shellHost else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        syncCatalogSnapshot()
        shellHost.push(ShellStackEntry(.detail(addonID: addonID, tab: tab)))
        renderCurrentTop(model: model)
        shellHost.morphFrame(to: .detail, compactLauncher: false, on: screen)
        shellHost.orderFront()
        shellHost.armClickOutsideDismiss { [weak self] in self?.dismissFromClickOutside() }
    }

    func ensurePanelIfNeeded(model: AppModel) {
        guard let shellHost else { return }
        shellHost.ensurePanel(
            initialContent: PaletteView(
                model: model,
                favorites: model.topFavorites(limit: 5),
                onRun: { [weak self] cmd in self?.runCommand(cmd) },
                onClose: { [weak shellHost] in shellHost?.hide() },
                onOpenBrowseCatalog: { [weak self] in self?.pushCatalog() },
                onOpenPreferences: { [weak self] in self?.pushSettings() },
                onRunShellNative: { [weak self] cmd in self?.runShellNative(cmd) },
                onReorderFavorite: { [weak self] from, to in self?.model?.moveFavorite(from: from, to: to) },
                onRemoveFavorite: { [weak self] cmd in self?.model?.removeFavorite(qualifiedId: cmd.qualifiedId) }
            ),
            size: ShellPreset.launcher.size(compactLauncher: false)
        )
    }

    func runShellNative(_ cmd: ShellNativeCommand) {
        switch cmd.kind {
        case .browseAddons: pushCatalog()
        case .preferences: pushSettings()
        }
    }

    func renderCurrentTop(model: AppModel) {
        guard let shellHost else { return }
        shellHost.setOnCancel { [weak self] in self?.popOrDismiss() }
        switch shellHost.stack.top.preset {
        case .launcher:
            guard case .launcher(let query, _, _) = shellHost.stack.top.state else { return }
            shellHost.setContent(PaletteView(
                model: model,
                favorites: model.topFavorites(limit: 5),
                initialQuery: query,
                onRun: { [weak self] cmd in self?.runCommand(cmd) },
                onClose: { [weak shellHost] in shellHost?.hide() },
                onOpenBrowseCatalog: { [weak self] in self?.pushCatalog() },
                onOpenPreferences: { [weak self] in self?.pushSettings() },
                onRunShellNative: { [weak self] cmd in self?.runShellNative(cmd) },
                onStateChange: { [weak shellHost] state in shellHost?.updateTopState(state) },
                onReorderFavorite: { [weak self] from, to in self?.model?.moveFavorite(from: from, to: to) },
                onRemoveFavorite: { [weak self] cmd in self?.model?.removeFavorite(qualifiedId: cmd.qualifiedId) }
            ))
        case .settings:
            shellHost.setContent(PrefsView(
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
                firstView: Binding(
                    get: { model.config.palette.firstView },
                    set: { value in
                        var config = model.config
                        config.palette.firstView = value
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
                    (
                        id: id,
                        name: model.addonDisplayName(id: id),
                        enabled: model.config.addons[id]?.enabled == true
                    )
                },
                onCheckForUpdates: { [weak self] in
                    Task { await self?.keepCurrent?.checkManual() }
                },
                onClose: { [weak self] in self?.popOrDismiss() },
                onApplyPreset: { preset in
                    var config = model.config
                    config.theme = preset
                    try? model.saveConfig(config)
                },
                onSelectInstalled: { [weak self] id in
                    self?.pushDetail(addonID: id, tab: .settings)
                }
            ))
        case .catalog:
            let vm = catalogViewModel(model: model)
            shellHost.setContent(BrowseCatalogView(
                viewModel: vm,
                onSelectCard: { [weak self] addonID in self?.pushDetail(addonID: addonID) },
                onOpenSettings: { [weak self] addonID in
                    self?.pushDetail(addonID: addonID, tab: .settings)
                },
                onOpen: { [weak self] addonID in self?.runPrimary(addonID: addonID) }
            ))
        case .detail:
            guard case .detail(let addonID, let tab) = shellHost.stack.top.state else { return }
            let vm = catalogViewModel(model: model)
            if let entry = vm.entries.first(where: { $0.id == addonID }) {
                var grants: [AddonPermission: Bool] = [:]
                for permission in entry.permissions where permission.isTCC {
                    grants[permission] = TCCGrantStatus.isGranted(permission)
                }
                let configState = self.addonConfigState(for: addonID)
                shellHost.setContent(AddonDetailView(
                    entry: entry,
                    isInstalled: vm.isInstalled(entry.id),
                    isEnabled: vm.isEnabled(entry.id),
                    isInstalling: vm.installingIDs.contains(entry.id),
                    updateAvailable: vm.updateAvailable(entry.id),
                    errorMessage: vm.errorMessage,
                    initialTab: tab,
                    permissionGrants: grants,
                    configSchema: configState.schema,
                    configValues: configState.values,
                    configError: configState.error,
                    onInstall: { Task { await vm.install(entry) } },
                    onUpdate: { Task { await vm.update(entry) } },
                    onEnabledChange: { vm.setEnabled(entry.id, enabled: $0) },
                    onUninstall: { vm.uninstall(id: entry.id, name: entry.name) },
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
                    onClose: { [weak self] in self?.popOrDismiss() },
                    onOpen: { [weak self] in self?.runPrimary(addonID: addonID) }
                ))
            }
        case .confirm, .list, .form, .grid:
            shellHost.renderFollowUpContent()
        }
    }

    // built once and reused so entries/filters survive push/pop
    func catalogViewModel(model: AppModel) -> BrowseCatalogViewModel {
        if let catalogViewModel { return catalogViewModel }
        guard let shellHost else { preconditionFailure("catalogViewModel(model:) requires shellHost to be set") }
        let vm = BrowseCatalogViewModel(model: model, shellHost: shellHost)
        catalogViewModel = vm
        return vm
    }

    // call before leaving catalog: the view model's @Published state survives push/pop, but the stack
    // snapshot needs updating for anything that reads the stack directly. scroll/selectedCardID aren't
    // tracked by the view model yet, so they keep their last-pushed value.
    func syncCatalogSnapshot() {
        guard let shellHost, let catalogViewModel, shellHost.stack.top.preset == .catalog else { return }
        shellHost.updateTopState(.catalog(
            category: catalogViewModel.selection.category,
            subcategory: catalogViewModel.selection.subcategory,
            tags: catalogViewModel.selectedTags,
            query: catalogViewModel.searchText,
            scroll: 0,
            selectedCardID: nil
        ))
    }
}
