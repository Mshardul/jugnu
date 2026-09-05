import Foundation
import JugnuCore
import JugnuUI
import Combine

@MainActor
final class BrowseCatalogViewModel: ObservableObject, BrowseCatalogViewModelProtocol {
    @Published var entries: [RegistryEntry] = []
    @Published var selection: CatalogSidebarSelection = .all
    @Published var selectedTags: Set<String> = []
    @Published var searchText: String = ""
    @Published var staleMessage: String?
    @Published var errorMessage: String?
    @Published var installingIDs: Set<String> = []
    /// Bumped after install/enable/uninstall mutate `model` so views reading
    /// `isInstalled`/`isEnabled` (which pull live from `model`, not `@Published`
    /// state) redraw. Those two methods have no other observable output.
    @Published private(set) var refreshTick = 0

    let categories = CatalogTaxonomy.categories
    private let model: AppModel
    private let shellHost: ShellHost

    init(model: AppModel, shellHost: ShellHost) {
        self.model = model
        self.shellHost = shellHost
    }

    var filtered: [RegistryEntry] {
        filterCatalog(
            entries: entries,
            category: selection.category,
            subcategory: selection.subcategory,
            tags: selectedTags,
            search: searchText
        )
    }

    func isInstalled(_ id: String) -> Bool {
        model.installedAddonIDs().contains(id)
    }

    func isEnabled(_ id: String) -> Bool {
        model.config.addons[id]?.enabled == true
    }

    func updateAvailable(_ id: String) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }) else { return false }
        let installed = model.installer.readInstalledAddonVersions()[id]
        return AddonUpdate.isAvailable(installed: installed, registry: entry.version)
    }

    func load() async {
        guard let url = URL(string: model.config.shell.registryURL) else {
            errorMessage = "The catalog URL isn't valid."
            return
        }
        let result = await RegistryClient().fetchWithCache(from: url, cacheFile: model.paths.registryCacheFile)
        switch result {
        case .fresh(let fetched):
            entries = fetched
            staleMessage = nil
            errorMessage = nil
        case .cached(let cached, let failure):
            entries = cached
            staleMessage = UserFacingError.cachedCatalogMessage(for: failure)
            errorMessage = nil
        case .unavailable(let failure):
            errorMessage = UserFacingError.message(for: failure)
        }
    }

    func install(_ entry: RegistryEntry) async {
        installingIDs.insert(entry.id)
        defer {
            installingIDs.remove(entry.id)
            refreshTick += 1
        }
        guard ReplaceWhileTracked.proceed(
            addonID: entry.id,
            paths: model.paths,
            host: model.processHost
        ) else { return }
        do {
            try await model.installer.install(
                entry: entry,
                enable: true,
                catalog: entries,
                installedVersions: model.installer.readInstalledAddonVersions(),
                confirmDependencies: { plan in
                    await MainActor.run { DependencyInstallDisclosure.confirm(plan) }
                }
            )
            try? model.bootstrapDaemons(id: entry.id)
            model.refreshIndex()
            errorMessage = nil
        } catch {
            if let installer = error as? AddonInstallerError,
               case .dependencyDisclosureDeclined = installer {
                errorMessage = nil
                return
            }
            errorMessage = UserFacingError.message(for: error)
        }
    }

    func update(_ entry: RegistryEntry) async {
        installingIDs.insert(entry.id)
        defer {
            installingIDs.remove(entry.id)
            refreshTick += 1
        }
        guard ReplaceWhileTracked.proceed(
            addonID: entry.id,
            paths: model.paths,
            host: model.processHost
        ) else { return }
        let preserveEnabled = model.config.addons[entry.id]?.enabled ?? false
        do {
            try await model.installer.install(
                entry: entry,
                enable: preserveEnabled,
                catalog: entries,
                installedVersions: model.installer.readInstalledAddonVersions(),
                confirmDependencies: { plan in
                    await MainActor.run { DependencyInstallDisclosure.confirm(plan) }
                }
            )
            try? model.bootstrapDaemons(id: entry.id)
            model.refreshIndex()
            errorMessage = nil
        } catch {
            if let installer = error as? AddonInstallerError,
               case .dependencyDisclosureDeclined = installer {
                errorMessage = nil
                return
            }
            errorMessage = UserFacingError.message(for: error)
        }
    }

    func setEnabled(_ id: String, enabled: Bool) {
        if !enabled {
            guard DisableWhileTracked.proceed(addonID: id, host: model.processHost) else { return }
        }
        do {
            try model.setEnabled(id: id, enabled: enabled)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
        refreshTick += 1
    }

    func uninstall(id: String, name: String) {
        AddonUninstallPresenter.present(id: id, name: name, model: model, shellHost: shellHost) { [weak self] in
            self?.model.refreshIndex()
            self?.errorMessage = nil
            self?.refreshTick += 1
        }
    }
}
