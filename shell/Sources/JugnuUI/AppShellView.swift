import JugnuCore
import SwiftUI

@MainActor
public final class AppShellChromeModel: ObservableObject {
    @Published public var navigation = AppNavigation.freshHome()
    @Published public var layout: HomeLayoutSnapshot?
    @Published public var linesByDefinition: [String: [String]] = [:]
    @Published public var actions: [AppShellSearchAction] = []

    public init() {}
}

public struct AppShellView<Pages: View>: View {
    @ObservedObject var chrome: AppShellChromeModel
    var onPage: (AppShellPage) -> Void
    var onDismiss: () -> Void
    var onOpenSearch: () -> Void
    var onTypeToSearch: (String) -> Void
    var onSearchBackdrop: () -> Void
    var onRunAction: (String) -> Void
    var onOpenDestination: (AppShellPage) -> Void
    var pages: () -> Pages

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(
        chrome: AppShellChromeModel,
        onPage: @escaping (AppShellPage) -> Void,
        onDismiss: @escaping () -> Void,
        onOpenSearch: @escaping () -> Void,
        onTypeToSearch: @escaping (String) -> Void,
        onSearchBackdrop: @escaping () -> Void,
        onRunAction: @escaping (String) -> Void,
        onOpenDestination: @escaping (AppShellPage) -> Void,
        @ViewBuilder pages: @escaping () -> Pages
    ) {
        self.chrome = chrome
        self.onPage = onPage
        self.onDismiss = onDismiss
        self.onOpenSearch = onOpenSearch
        self.onTypeToSearch = onTypeToSearch
        self.onSearchBackdrop = onSearchBackdrop
        self.onRunAction = onRunAction
        self.onOpenDestination = onOpenDestination
        self.pages = pages
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
    }

    private var palette: ShellPalette {
        ShellPalette(theme: theme, colorScheme: colorScheme)
    }

    public var body: some View {
        let navigation = chrome.navigation
        VStack(spacing: 0) {
            topBar(navigation)
            ZStack {
                HomeGridView(
                    layout: chrome.layout,
                    linesByDefinition: chrome.linesByDefinition,
                    acceptsTyping: navigation.page == .home,
                    onOpenCatalog: { onPage(.catalog) },
                    onTypeToSearch: onTypeToSearch
                )
                .opacity(navigation.page == .home || navigation.page == .search ? 1 : 0)
                .allowsHitTesting(navigation.page == .home)
                .accessibilityHidden(navigation.page != .home && navigation.page != .search)
                if navigation.page != .home, navigation.page != .search {
                    pages()
                }
                if navigation.page == .search {
                    AppShellSearchLayer(
                        query: navigation.searchQuery,
                        actions: chrome.actions,
                        palette: palette,
                        onBackdrop: onSearchBackdrop,
                        onRunAction: onRunAction,
                        onOpenDestination: onOpenDestination
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.frame)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
    }

    private func topBar(_ navigation: AppNavigation) -> some View {
        ZStack {
            HStack {
                shellBrand
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ShellIconButton(
                        systemName: "magnifyingglass",
                        label: "Search",
                        active: navigation.page == .search,
                        palette: palette,
                        action: onOpenSearch
                    )
                    ShellIconButton(
                        systemName: "xmark",
                        label: "Close",
                        palette: palette,
                        action: onDismiss
                    )
                }
            }
            primaryNav(navigation)
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border).frame(height: 1)
        }
    }

    private var shellBrand: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(palette.accent)
                .frame(width: 18, height: 18)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 5, height: 5)
                        .offset(x: 4, y: 3)
                }
                .shadow(color: palette.accent.opacity(0.7), radius: 6)
            Text("Jugnu")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
        }
    }

    private func primaryNav(_ navigation: AppNavigation) -> some View {
        HStack(spacing: 2) {
            navButton(.home, title: "Home", navigation: navigation)
            navButton(.catalog, title: "Catalog", navigation: navigation)
            navButton(.preferences, title: "Preferences", navigation: navigation)
        }
        .padding(3)
        .frame(height: 38)
        .background(palette.soft)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Primary")
    }

    private func navButton(_ page: AppShellPage, title: String, navigation: AppNavigation) -> some View {
        let active = isActive(page, navigation: navigation)
        return Button(title) { onPage(page) }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? palette.text : palette.muted)
            .padding(.horizontal, 15)
            .frame(height: 32)
            .background(active ? palette.raised : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: active ? .black.opacity(0.35) : .clear, radius: 2, y: 1)
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func isActive(_ page: AppShellPage, navigation: AppNavigation) -> Bool {
        if page == .home {
            return navigation.page == .home || navigation.page == .search
        }
        return navigation.page == page
    }
}

private struct AppShellSearchLayer: View {
    var actions: [AppShellSearchAction]
    var palette: ShellPalette
    var onBackdrop: () -> Void
    var onRunAction: (String) -> Void
    var onOpenDestination: (AppShellPage) -> Void

    @State private var query: String
    @State private var selection = 0
    @State private var lastInvoke: (id: String, at: Date)?
    @FocusState private var fieldFocused: Bool

    init(
        query: String,
        actions: [AppShellSearchAction],
        palette: ShellPalette,
        onBackdrop: @escaping () -> Void,
        onRunAction: @escaping (String) -> Void,
        onOpenDestination: @escaping (AppShellPage) -> Void
    ) {
        self.actions = actions
        self.palette = palette
        self.onBackdrop = onBackdrop
        self.onRunAction = onRunAction
        self.onOpenDestination = onOpenDestination
        _query = State(initialValue: query)
    }

    private var rows: [AppShellSearchRow] {
        appShellSearchRows(actions: actions, query: query)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.55)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onBackdrop)
            .accessibilityLabel("Dismiss search")
            .accessibilityAddTraits(.isButton)
            searchCard
                .padding(.top, 72)
                .padding(.horizontal, 48)
        }
        .onAppear { fieldFocused = true }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !rows.isEmpty {
                selection = min(selection + 1, rows.count - 1)
            }
            return .handled
        }
        .onChange(of: query) { _, _ in
            selection = 0
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if rows.isEmpty {
                        Text("No matching actions.")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    resultGroup(
                        title: "Actions",
                        kind: "Action",
                        matching: {
                            if case .action = $0 {
                                true
                            } else {
                                false
                            }
                        }
                    )
                    resultGroup(
                        title: "Addons and settings",
                        kind: "Page",
                        matching: {
                            if case .page = $0 {
                                true
                            } else {
                                false
                            }
                        }
                    )
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 420)
            searchFooter
        }
        .frame(maxWidth: 680)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.borderStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Search")
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.muted)
            TextField("Search Jugnu", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(palette.text)
                .focused($fieldFocused)
                .accessibilityLabel("Search Jugnu")
                .onSubmit { activateSelection() }
            Text("esc")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border).frame(height: 1)
        }
    }

    private var searchFooter: some View {
        HStack(spacing: 14) {
            Text("↑↓ Select")
            Text("↵ Open")
            Text("esc Close")
        }
        .font(.system(size: 9))
        .foregroundStyle(palette.muted)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private func resultGroup(
        title: String,
        kind: String,
        matching: (AppShellSearchRow) -> Bool
    ) -> some View {
        let indexed = rows.enumerated().filter { matching($0.element) }
        if !indexed.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.muted)
                    .tracking(0.8)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                ForEach(indexed, id: \.offset) { index, row in
                    searchResult(row, index: index, kind: kind)
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func searchResult(_ row: AppShellSearchRow, index: Int, kind: String) -> some View {
        let selected = index == selection
        return Button {
            selection = index
            activate(row)
        } label: {
            HStack(spacing: 10) {
                ShellGlyphTile(systemName: kind == "Action" ? "bolt" : "square.grid.2x2", palette: palette)
                resultTitle(row)
                Spacer(minLength: 8)
                Text(kind)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.muted)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 47, alignment: .leading)
            .background(selected ? palette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: row))
    }

    private func resultTitle(_ row: AppShellSearchRow) -> some View {
        switch row {
        case let .action(action):
            return Text("\(action.addonName) › \(action.actionTitle)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
        case let .page(_, title):
            return Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
        }
    }

    private func label(for row: AppShellSearchRow) -> String {
        switch row {
        case let .action(action):
            appShellSearchLabel(addonName: action.addonName, actionTitle: action.actionTitle)
        case let .page(_, title):
            title
        }
    }

    private func activateSelection() {
        guard rows.indices.contains(selection) else { return }
        activate(rows[selection])
    }

    private func activate(_ row: AppShellSearchRow) {
        switch row {
        case let .action(action):
            let now = Date()
            guard PaletteInvokeDebounce.shouldRun(id: action.qualifiedID, now: now, last: lastInvoke) else { return }
            lastInvoke = (action.qualifiedID, now)
            onRunAction(action.qualifiedID)
        case let .page(page, _):
            onOpenDestination(page)
        }
    }
}
