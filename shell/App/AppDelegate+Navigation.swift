import AppKit
import JugnuCore
import JugnuUI
import SwiftUI

@MainActor
extension AppDelegate {
    func pushSettings() {
        openAppShellPage(.preferences)
    }

    func pushCatalog() {
        openAppShellPage(.catalog)
    }

    func pushDetail(addonID: String, tab: AddonDetailTab = .overview) {
        guard let model, let shellHost else { return }
        var navigation = shellHost.appShellNavigation ?? .freshHome()
        navigation.page = .catalog
        navigation.catalog.detail = AddonDetailRoute(addonID: addonID, section: addonDetailSection(tab))
        if shellHost.isVisible, shellHost.stack.top.preset == .appShell {
            shellHost.updateAppShell(navigation)
            renderCurrentTop(model: model)
            return
        }
        guard let screen = screenUnderPointer() else { return }
        openAppShell(navigation, on: screen, model: model)
    }

    func ensurePanelIfNeeded(model _: AppModel) {
        guard let shellHost else { return }
        shellHost.ensurePanel(
            initialContent: EmptyView(),
            size: NSSize(width: 960, height: 640)
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
        shellHost.setOnCancel { [weak self] in self?.handlePanelEscape() }
        shellHost.setOnCommandW { [weak self] in self?.handlePanelCommandW() }
        switch shellHost.stack.top.preset {
        case .launcher:
            guard case let .launcher(query, _, _) = shellHost.stack.top.state else { return }
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
            guard case let .detail(addonID, tab) = shellHost.stack.top.state else { return }
            shellHost.setContent(hostedAddonDetail(
                model: model,
                addonID: addonID,
                tab: tab,
                onClose: { [weak self] in self?.popOrDismiss() }
            ))
        case .confirm, .list, .form, .grid:
            shellHost.renderFollowUpContent()
        case .appShell:
            renderAppShell(model: model)
        }
    }

    /// built once and reused so entries/filters survive push/pop
    func catalogViewModel(model: AppModel) -> BrowseCatalogViewModel {
        if let catalogViewModel {
            return catalogViewModel
        }
        guard let shellHost else { preconditionFailure("catalogViewModel(model:) requires shellHost to be set") }
        let vm = BrowseCatalogViewModel(model: model, shellHost: shellHost)
        catalogViewModel = vm
        return vm
    }

    /// call before leaving catalog: the view model's @Published state survives push/pop, but the stack
    /// snapshot needs updating for anything that reads the stack directly. scroll/selectedCardID aren't
    /// tracked by the view model yet, so they keep their last-pushed value.
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
