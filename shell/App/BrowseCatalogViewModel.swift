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

        let plan: DependencyPlan?
        do {
            plan = try registryDependencyPlan(for: entry)
        } catch let error as DependencyResolverError {
            errorMessage = UserFacingError.message(for: AddonInstallerError.dependency(error))
            return
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return
        }

        let disclosedDepIDs = Set((plan?.dependencies ?? []).map(\.id))
        if let ui = installDisclosureUI(entry: entry, plan: plan) {
            guard await confirmDisclosure(
                ui: ui,
                commandId: "shell.install.\(entry.id)"
            ) else { return }
        }

        await runInstall(
            entry: entry,
            enable: true,
            disclosedDepIDs: disclosedDepIDs
        )
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

        let growth = PermissionsSet.grew(
            from: installedPermissions(id: entry.id),
            to: entry.permissions
        )
        if !growth.isEmpty {
            guard await confirmDisclosure(
                ui: confirmPermissionsGrewUI(addonName: entry.name, newPermissions: growth),
                commandId: "shell.update.\(entry.id)"
            ) else { return }
        }

        let plan: DependencyPlan?
        do {
            plan = try registryDependencyPlan(for: entry)
        } catch let error as DependencyResolverError {
            errorMessage = UserFacingError.message(for: AddonInstallerError.dependency(error))
            return
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return
        }

        let disclosedDepIDs = Set((plan?.dependencies ?? []).map(\.id))
        if let plan, plan.needsDisclosure {
            guard await confirmDisclosure(
                ui: confirmInstallDisclosureUI(
                    permissionsTitle: "Update \(entry.name)?",
                    permissionsBody: nil,
                    dependencyPlan: plan,
                    confirmLabel: "Update"
                ),
                commandId: "shell.update-deps.\(entry.id)"
            ) else { return }
        }

        let preserveEnabled = model.config.addons[entry.id]?.enabled ?? false
        await runInstall(
            entry: entry,
            enable: preserveEnabled,
            disclosedDepIDs: disclosedDepIDs
        )
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

    private func confirmDisclosure(ui: UIDescriptor, commandId: String) async -> Bool {
        await InstallDisclosurePresenter.confirm(ui: ui, shellHost: shellHost, commandId: commandId)
    }

    private func installedPermissions(id: String) -> [AddonPermission] {
        let root = model.paths.addonsDir.appendingPathComponent(id)
        guard let manifest = try? ManifestLoader.load(from: root) else { return [] }
        return manifest.permissions
    }

    private func registryDependencyPlan(for entry: RegistryEntry) throws -> DependencyPlan? {
        guard !entry.dependencies.isEmpty else { return nil }
        let catalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, DeclaredAddon(entry: $0)) })
        return try DependencyResolver.plan(
            root: DeclaredAddon(entry: entry),
            catalog: catalog,
            installed: model.installer.readInstalledAddonVersions()
        )
    }

    private func installDisclosureUI(entry: RegistryEntry, plan: DependencyPlan?) -> UIDescriptor? {
        let permissionsUI = entry.permissions.isEmpty
            ? nil
            : confirmPermissionsInstallUI(addonName: entry.name, permissions: entry.permissions)
        let needsDeps = plan?.needsDisclosure ?? false
        guard permissionsUI != nil || needsDeps else { return nil }
        if let permissionsUI, !needsDeps {
            return permissionsUI
        }
        return confirmInstallDisclosureUI(
            permissionsTitle: "Install \(entry.name)?",
            permissionsBody: permissionsUI?.message,
            dependencyPlan: plan
        )
    }

    private func runInstall(
        entry: RegistryEntry,
        enable: Bool,
        disclosedDepIDs: Set<String>
    ) async {
        do {
            try await model.installer.install(
                entry: entry,
                enable: enable,
                catalog: entries,
                installedVersions: model.installer.readInstalledAddonVersions(),
                confirmDependencies: { [weak self] plan in
                    guard let self else { return false }
                    let postIDs = Set(plan.dependencies.map(\.id))
                    if plan.needsDisclosure, !disclosedDepIDs.isSuperset(of: postIDs) {
                        return await self.confirmDisclosure(
                            ui: confirmInstallDisclosureUI(
                                permissionsTitle: "Install \(plan.primaryName)?",
                                permissionsBody: nil,
                                dependencyPlan: plan
                            ),
                            commandId: "shell.install-deps.\(entry.id)"
                        )
                    }
                    return true
                }
            )
            try? model.bootstrapDaemons(id: entry.id)
            model.refreshIndex()
            errorMessage = nil
        } catch {
            if let installer = error as? AddonInstallerError,
               case .dependencyDisclosureDeclined = installer
            {
                errorMessage = nil
                return
            }
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
