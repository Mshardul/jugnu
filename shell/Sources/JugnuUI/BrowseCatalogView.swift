import JugnuCore
import SwiftUI

@MainActor
public protocol BrowseCatalogViewModelProtocol: ObservableObject {
    var entries: [RegistryEntry] { get }
    var filtered: [RegistryEntry] { get }
    var selection: CatalogSidebarSelection { get set }
    var selectedTags: Set<String> { get set }
    var searchText: String { get set }
    var staleMessage: String? { get }
    var errorMessage: String? { get }
    var installingIDs: Set<String> { get }
    var categories: [String] { get }

    func isInstalled(_ id: String) -> Bool
    func isEnabled(_ id: String) -> Bool
    func updateAvailable(_ id: String) -> Bool
    func isFavoriteAddon(_ id: String) -> Bool
    func toggleFavoriteAddon(_ id: String)
    var recentAddonIDs: [String] { get }
    func load() async
    func install(_ entry: RegistryEntry) async
    func update(_ entry: RegistryEntry) async
    func setEnabled(_ id: String, enabled: Bool)
    func uninstall(id: String, name: String)
}

public struct BrowseCatalogView<VM: BrowseCatalogViewModelProtocol>: View {
    @ObservedObject var viewModel: VM
    var catalog: CatalogNavigation
    var onCatalogChange: (CatalogNavigation) -> Void
    var onSelectCard: (String) -> Void
    var onOpenSettings: (String) -> Void
    var onOpen: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared
    @State private var installTasks: [String: Task<Void, Never>] = [:]

    public init(
        viewModel: VM,
        catalog: CatalogNavigation = CatalogNavigation(),
        onCatalogChange: @escaping (CatalogNavigation) -> Void = { _ in },
        onSelectCard: @escaping (String) -> Void,
        onOpenSettings: @escaping (String) -> Void = { _ in },
        onOpen: @escaping (String) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.catalog = catalog
        self.onCatalogChange = onCatalogChange
        self.onSelectCard = onSelectCard
        self.onOpenSettings = onOpenSettings
        self.onOpen = onOpen
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        let palette = ShellPalette(theme: theme, colorScheme: colorScheme)
        let visible = visibleEntries
        HStack(spacing: 0) {
            sidebar(palette: palette)
                .frame(width: 212)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    catalogHead(palette: palette)
                    chips(palette: palette)
                    if let staleMessage = viewModel.staleMessage {
                        catalogBanner(staleMessage, palette: palette)
                    }
                    if let errorMessage = viewModel.errorMessage {
                        catalogBanner(errorMessage, palette: palette)
                    }
                    if catalog.section == .discover {
                        discover(palette: palette)
                    }
                    if visible.isEmpty {
                        emptyResults(palette: palette)
                    } else {
                        if catalog.section == .discover {
                            sectionTitle("All Addons", trailing: "\(visible.count) in registry", palette: palette)
                        }
                        cardGrid(visible, palette: palette)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 46)
            }
            .background(palette.frame)
        }
        .background(palette.frame)
        .frame(minWidth: 720, minHeight: 480)
        .task { await viewModel.load() }
        .onAppear { syncViewModel(to: catalog) }
        .onDisappear {
            for task in installTasks.values {
                task.cancel()
            }
            installTasks.removeAll()
        }
    }

    private var visibleEntries: [RegistryEntry] {
        scoped(viewModel.entries, section: catalog.section).filter { entry in
            matchesQuery(entry) && matchesFilters(entry)
        }
    }

    private var recommended: [RegistryEntry] {
        viewModel.entries.filter { entry in
            entry.tags.contains("recommended") || ShellConfig.recommendedAddonIDs.contains(entry.id)
        }
    }

    private func scoped(_ entries: [RegistryEntry], section: CatalogBrowse) -> [RegistryEntry] {
        switch section {
        case .discover, .all:
            entries
        case .installed:
            entries.filter { viewModel.isInstalled($0.id) }
        case .updates:
            entries.filter { viewModel.updateAvailable($0.id) }
        case .recent:
            viewModel.recentAddonIDs.compactMap { id in entries.first { $0.id == id } }
        case .favorites:
            entries.filter { viewModel.isFavoriteAddon($0.id) }
        case let .category(name, subcategory):
            entries.filter { entry in
                entry.category == name && (subcategory == nil || entry.subcategory == subcategory)
            }
        }
    }

    private func matchesQuery(_ entry: RegistryEntry) -> Bool {
        let query = catalog.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [entry.name, entry.summary, entry.category, entry.subcategory ?? ""].joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(query)
    }

    private func matchesFilters(_ entry: RegistryEntry) -> Bool {
        for filter in catalog.filters {
            if filter == Self.noExtraPermissions {
                if !entry.permissions.isEmpty {
                    return false
                }
            } else if !entry.tags.contains(filter) {
                return false
            }
        }
        return true
    }

    private func replace(_ mutate: (inout CatalogNavigation) -> Void) {
        var next = catalog
        mutate(&next)
        syncViewModel(to: next)
        onCatalogChange(next)
    }

    private func syncViewModel(to navigation: CatalogNavigation) {
        viewModel.searchText = navigation.query
        viewModel.selectedTags = Set(navigation.filters.filter { CatalogTaxonomy.tags.contains($0) })
        switch navigation.section {
        case let .category(name, subcategory?):
            viewModel.selection = .subcategory(category: name, name: subcategory)
        case let .category(name, nil):
            viewModel.selection = .category(name)
        default:
            viewModel.selection = .all
        }
    }

    private func select(_ section: CatalogBrowse) {
        replace { $0.section = section }
    }

    private func startInstall(_ entry: RegistryEntry) {
        guard installTasks[entry.id] == nil else { return }
        installTasks[entry.id] = Task {
            await viewModel.install(entry)
            installTasks[entry.id] = nil
        }
    }

    private func startUpdate(_ entry: RegistryEntry) {
        guard installTasks[entry.id] == nil else { return }
        installTasks[entry.id] = Task {
            await viewModel.update(entry)
            installTasks[entry.id] = nil
        }
    }

    private func card(_ entry: RegistryEntry) -> some View {
        AddonCardView(
            entry: entry,
            isInstalled: viewModel.isInstalled(entry.id),
            isEnabled: viewModel.isEnabled(entry.id),
            isInstalling: viewModel.installingIDs.contains(entry.id),
            updateAvailable: viewModel.updateAvailable(entry.id),
            isFavorite: viewModel.isFavoriteAddon(entry.id),
            onInstall: { startInstall(entry) },
            onUpdate: { startUpdate(entry) },
            onEnabledChange: { viewModel.setEnabled(entry.id, enabled: $0) },
            onUninstall: { viewModel.uninstall(id: entry.id, name: entry.name) },
            onTap: { onSelectCard(entry.id) },
            onOpenSettings: { onOpenSettings(entry.id) },
            onOpen: { onOpen(entry.id) },
            onFavorite: { viewModel.toggleFavoriteAddon(entry.id) }
        )
    }
}

extension BrowseCatalogView {
    private func catalogHead(palette: ShellPalette) -> some View {
        let copy = scopeCopy(catalog.section)
        return HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(copy.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .tracking(-0.4)
                Text(copy.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                TextField(
                    "Search this view",
                    text: Binding(
                        get: { catalog.query },
                        set: { query in replace { $0.query = query } }
                    )
                )
                .textFieldStyle(.plain)
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.muted)
            .padding(.horizontal, 11)
            .frame(width: 320, height: 36)
            .background(palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
        }
        .padding(.bottom, 16)
    }

    private func chips(palette: ShellPalette) -> some View {
        let tags = CatalogTaxonomy.tags.filter { tag in
            viewModel.entries.contains { $0.tags.contains(tag) }
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                chip("All", selected: catalog.filters.isEmpty, palette: palette) {
                    replace { $0.filters = [] }
                }
                chip(
                    "No extra permissions",
                    selected: catalog.filters.contains(Self.noExtraPermissions),
                    palette: palette
                ) {
                    toggleFilter(Self.noExtraPermissions)
                }
                ForEach(tags, id: \.self) { tag in
                    chip(tag, selected: catalog.filters.contains(tag), palette: palette) {
                        toggleFilter(tag)
                    }
                }
            }
        }
        .padding(.bottom, 18)
    }

    private func toggleFilter(_ filter: String) {
        replace { navigation in
            if navigation.filters.contains(filter) {
                navigation.filters.removeAll { $0 == filter }
            } else {
                navigation.filters.append(filter)
            }
        }
    }

    private func chip(_ title: String, selected: Bool, palette: ShellPalette,
                      action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? palette.accent : palette.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? palette.accentSoft : palette.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(selected ? palette.accent.opacity(0.45) : palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func catalogBanner(_ message: String, palette: ShellPalette) -> some View {
        Text(message)
            .font(.system(size: 10))
            .foregroundStyle(palette.sub)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.accent.opacity(0.35), lineWidth: 1)
            )
            .padding(.bottom, 13)
    }

    @ViewBuilder
    private func discover(palette: ShellPalette) -> some View {
        let picks = Array(recommended.prefix(3))
        if !picks.isEmpty {
            sectionTitle("Recommended", trailing: "Curated in registry order", palette: palette)
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(picks.enumerated()), id: \.element.id) { index, entry in
                    featureCard(entry, primary: index == 0, palette: palette)
                }
            }
            .padding(.bottom, 22)
        }
        sectionTitle("Browse by category", trailing: "No personalization", palette: palette)
        categoryLinks(palette: palette)
            .padding(.bottom, 23)
    }

    private func sectionTitle(_ title: String, trailing: String, palette: ShellPalette) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
            Spacer()
            Text(trailing)
                .font(.system(size: 9))
                .foregroundStyle(palette.muted)
        }
        .padding(.bottom, 10)
    }

    private func featureCard(_ entry: RegistryEntry, primary: Bool, palette: ShellPalette) -> some View {
        Button {
            onSelectCard(entry.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    addonIcon(entry, palette: palette, side: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Text(featureMeta(entry))
                            .font(.system(size: 9))
                            .foregroundStyle(palette.muted)
                    }
                }
                Text(entry.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
                    .lineLimit(3)
                    .padding(.top, 10)
                Spacer(minLength: 8)
                Text(entry.trust != .community ? "\(entry.trust.label) Addon" : entry.category)
                    .font(.system(size: 9))
                    .foregroundStyle(palette.muted)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(primary ? palette.accentSoft.opacity(0.55) : palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(primary ? palette.accent.opacity(0.35) : palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func featureMeta(_ entry: RegistryEntry) -> String {
        if viewModel.isInstalled(entry.id) {
            return viewModel.isEnabled(entry.id) ? "Installed · Enabled" : "Installed · Disabled"
        }
        return entry.category
    }

    private func categoryLinks(palette: ShellPalette) -> some View {
        let groups = viewModel.categories.compactMap { category -> (String, Int)? in
            let count = viewModel.entries.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
        return HStack(spacing: 8) {
            ForEach(groups, id: \.0) { category, count in
                Button {
                    select(.category(category, subcategory: nil))
                } label: {
                    Text("\(category) · \(count)")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.sub)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(palette.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func cardGrid(_ entries: [RegistryEntry], palette _: ShellPalette) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(entries, id: \.id) { entry in
                card(entry)
            }
        }
    }

    private func emptyResults(palette: ShellPalette) -> some View {
        VStack(spacing: 6) {
            Text("No Addons match these filters")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.sub)
            Text("Remove a filter or search the complete registry.")
                .font(.system(size: 10))
                .foregroundStyle(palette.muted)
            Button("Clear filters") {
                replace {
                    $0.filters = []
                    $0.query = ""
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    private func sidebar(palette: ShellPalette) -> some View {
        let installed = viewModel.entries.filter { viewModel.isInstalled($0.id) }.count
        let updates = viewModel.entries.filter { viewModel.updateAvailable($0.id) }.count
        let favorites = viewModel.entries.filter { viewModel.isFavoriteAddon($0.id) }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sideLabel("Browse", palette: palette)
                sideItem(
                    "Discover",
                    symbol: "sparkle",
                    selected: catalog.section == .discover,
                    count: nil,
                    palette: palette
                ) {
                    select(.discover)
                }
                sideItem(
                    "All Addons",
                    symbol: "square.grid.2x2",
                    selected: catalog.section == .all,
                    count: viewModel.entries.count,
                    palette: palette
                ) {
                    select(.all)
                }
                sideItem(
                    "Installed",
                    symbol: "shippingbox",
                    selected: catalog.section == .installed,
                    count: installed,
                    palette: palette
                ) {
                    select(.installed)
                }
                sideItem(
                    "Updates",
                    symbol: "arrow.triangle.2.circlepath",
                    selected: catalog.section == .updates,
                    count: updates > 0 ? updates : nil,
                    palette: palette
                ) {
                    select(.updates)
                }
                sideItem("Recent", symbol: "clock", selected: catalog.section == .recent, count: nil,
                         palette: palette)
                {
                    select(.recent)
                }
                sideItem(
                    "Favorites",
                    symbol: "star",
                    selected: catalog.section == .favorites,
                    count: favorites > 0 ? favorites : nil,
                    palette: palette
                ) {
                    select(.favorites)
                }
                sideLabel("Categories", palette: palette)
                    .padding(.top, 14)
                ForEach(viewModel.categories, id: \.self) { category in
                    categoryRows(category, palette: palette)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .background(palette.soft)
        .overlay(alignment: .trailing) {
            Rectangle().fill(palette.border).frame(width: 1)
        }
    }

    @ViewBuilder
    private func categoryRows(_ category: String, palette: ShellPalette) -> some View {
        let selected = catalog.section == .category(category, subcategory: nil)
        sideItem(category, symbol: "square.grid.2x2", selected: selected, count: nil, palette: palette) {
            select(.category(category, subcategory: nil))
        }
        let subcategories = Set(viewModel.entries.filter { $0.category == category }.compactMap(\.subcategory))
        if subcategories.count >= 2 {
            ForEach(Array(subcategories).sorted(), id: \.self) { name in
                let subSelected = catalog.section == .category(category, subcategory: name)
                Button {
                    select(.category(category, subcategory: name))
                } label: {
                    Text(name)
                        .font(.system(size: 11.5, weight: subSelected ? .semibold : .regular))
                        .foregroundStyle(subSelected ? palette.accent : palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 32)
                        .padding(.trailing, 10)
                        .frame(height: 34)
                        .background(subSelected ? palette.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sideLabel(_ title: String, palette: ShellPalette) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.muted)
            .tracking(1)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }

    private func sideItem(
        _ title: String,
        symbol: String,
        selected: Bool,
        count: Int?,
        palette: ShellPalette,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 15, height: 15)
                Text(title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                Spacer(minLength: 4)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.muted)
                }
            }
            .foregroundStyle(selected ? palette.accent : palette.sub)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(selected ? palette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func addonIcon(_ entry: RegistryEntry, palette: ShellPalette, side: CGFloat) -> some View {
        Image(systemName: catalogSymbol(for: entry.category))
            .font(.system(size: side * 0.48, weight: .medium))
            .foregroundStyle(palette.sub)
            .frame(width: side, height: side)
            .background(palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
    }

    private func scopeCopy(_ section: CatalogBrowse) -> (title: String, subtitle: String) {
        switch section {
        case .discover:
            return ("Discover", "A restrained selection from the registry, followed by clear ways to browse.")
        case .all:
            return ("All Addons", "Everything currently in the registry.")
        case .installed:
            return ("Installed", "Addons already on this Mac.")
        case .updates:
            return ("Updates", "Installed Addons with a newer version in the registry.")
        case .recent:
            return ("Recent", "Addons you have used recently.")
        case .favorites:
            return ("Favorites", "Addons you starred.")
        case let .category(name, subcategory):
            let title = subcategory ?? name
            return (title, "Addons in \(name).")
        }
    }

    private static var noExtraPermissions: String {
        "no-extra-permissions"
    }
}

func catalogSymbol(for category: String) -> String {
    switch category {
    case "Clipboard": "doc.on.clipboard"
    case "Focus": "timer"
    case "System": "gearshape"
    case "Info": "info.circle"
    case "Notes": "note.text"
    default: "square.grid.2x2"
    }
}
