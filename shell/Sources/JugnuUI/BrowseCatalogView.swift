import SwiftUI
import JugnuCore

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
    func load() async
    func install(_ entry: RegistryEntry) async
    func setEnabled(_ id: String, enabled: Bool)
    func uninstall(id: String, name: String)
}

public struct BrowseCatalogView<VM: BrowseCatalogViewModelProtocol>: View {
    @ObservedObject var viewModel: VM
    var onSelectCard: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(viewModel: VM, onSelectCard: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.onSelectCard = onSelectCard
    }

    public var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        HStack(spacing: 0) {
            sidebar()
                .frame(width: 160)
            Divider()
            VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
                TextField("Search addons", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding([.horizontal, .top])

                tagChips(theme: theme)
                    .padding(.horizontal)

                if let staleMessage = viewModel.staleMessage {
                    PanelErrorBanner(message: staleMessage)
                        .padding(.horizontal)
                }
                if let errorMessage = viewModel.errorMessage {
                    PanelErrorBanner(message: errorMessage).padding(.horizontal)
                }

                if viewModel.filtered.isEmpty && !viewModel.entries.isEmpty {
                    Text("No addons match these filters.")
                        .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                            ForEach(viewModel.filtered, id: \.id) { entry in
                                AddonCardView(
                                    entry: entry,
                                    isInstalled: viewModel.isInstalled(entry.id),
                                    isEnabled: viewModel.isEnabled(entry.id),
                                    isInstalling: viewModel.installingIDs.contains(entry.id),
                                    onInstall: { Task { await viewModel.install(entry) } },
                                    onEnabledChange: { viewModel.setEnabled(entry.id, enabled: $0) },
                                    onUninstall: { viewModel.uninstall(id: entry.id, name: entry.name) },
                                    onTap: { onSelectCard(entry.id) }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .background(theme.background)
        .frame(minWidth: 720, minHeight: 480)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func sidebar() -> some View {
        List(selection: $viewModel.selection) {
            Text("All").tag(CatalogSidebarSelection.all)
            ForEach(viewModel.categories, id: \.self) { category in
                let subcats = Set(viewModel.entries.filter { $0.category == category }.compactMap { $0.subcategory })
                if subcats.count >= 2 {
                    DisclosureGroup(category) {
                        ForEach(Array(subcats).sorted(), id: \.self) { sub in
                            Text(sub).tag(CatalogSidebarSelection.subcategory(category: category, name: sub))
                        }
                    }
                    .tag(CatalogSidebarSelection.category(category))
                } else {
                    Text(category).tag(CatalogSidebarSelection.category(category))
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func tagChips(theme: JugnuThemeColors) -> some View {
        let available = availableTags(
            entries: viewModel.entries,
            category: viewModel.selection.category,
            subcategory: viewModel.selection.subcategory,
            search: viewModel.searchText
        )
        let visibleTags = CatalogTaxonomy.tags.filter { available.contains($0) }
        HStack {
            ForEach(visibleTags, id: \.self) { tag in
                let selected = viewModel.selectedTags.contains(tag)
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(selected ? theme.accent.opacity(0.2) : theme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(selected ? theme.accent : theme.textSecondary.opacity(0.3)))
                    .onTapGesture {
                        if selected { viewModel.selectedTags.remove(tag) } else { viewModel.selectedTags.insert(tag) }
                    }
            }
        }
    }
}
