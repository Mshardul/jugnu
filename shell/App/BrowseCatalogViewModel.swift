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

    let categories = CatalogTaxonomy.categories
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
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
        do {
            try await model.installer.install(entry: entry, enable: true)
            model.refreshIndex()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
        installingIDs.remove(entry.id)
    }

    func setEnabled(_ id: String, enabled: Bool) {
        do {
            try model.setEnabled(id: id, enabled: enabled)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    func uninstall(id: String, name: String) {
        AddonUninstallPresenter.present(id: id, name: name, model: model) { [weak self] in
            self?.model.refreshIndex()
        }
    }
}
