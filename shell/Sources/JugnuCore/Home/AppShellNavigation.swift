import Foundation

public enum AppShellPage: Equatable, Sendable {
    case home
    case search
    case editHome
    case catalog
    case preferences
    case focusedAddon
}

public enum AppShellControl: Equatable, Sendable {
    case invokeHotkey
    case escape
    case clickOutside
    case commandW
    case searchBackdrop
}

public enum AppShellControlEffect: Equatable, Sendable {
    case noOp
    case openFreshHome
    case hideAndClearRouteStack
    case ignore
    case closeSearchRestoreHome
    case exitEditHome
    case goHome
    case popDetailOrGoHome
    case popFocusedAddon
    case followCommandDismissPolicy
}

public enum CatalogBrowse: Equatable, Sendable {
    case discover
    case all
    case installed
    case updates
    case recent
    case favorites
    case category(String, subcategory: String?)
}

public enum AddonDetailSection: Equatable, Sendable {
    case overview
    case actions
    case widgets
    case settings
}

public struct AddonDetailRoute: Equatable, Sendable {
    public var addonID: String
    public var section: AddonDetailSection

    public init(addonID: String, section: AddonDetailSection) {
        self.addonID = addonID
        self.section = section
    }
}

public struct CatalogNavigation: Equatable, Sendable {
    public var section: CatalogBrowse
    public var query: String
    public var filters: [String]
    public var scroll: Double
    public var selectedCardID: String?
    public var detail: AddonDetailRoute?

    public init(
        section: CatalogBrowse = .discover,
        query: String = "",
        filters: [String] = [],
        scroll: Double = 0,
        selectedCardID: String? = nil,
        detail: AddonDetailRoute? = nil
    ) {
        self.section = section
        self.query = query
        self.filters = filters
        self.scroll = scroll
        self.selectedCardID = selectedCardID
        self.detail = detail
    }
}

public enum PreferencesSection: Equatable, Sendable {
    case appearance
    case installed
    case updates
    case general
}

public enum EditHomePanel: Equatable, Sendable {
    case library
    case inspector(instanceID: String)
}

public struct AppNavigation: Equatable, Sendable {
    public var page: AppShellPage
    public var homeScroll: Double
    public var searchQuery: String
    public var isEditingHome: Bool
    public var editPanel: EditHomePanel
    public var catalog: CatalogNavigation
    public var preferencesSection: PreferencesSection
    public var focusedOrigin: AppShellPage?

    public init(
        page: AppShellPage = .home,
        homeScroll: Double = 0,
        searchQuery: String = "",
        isEditingHome: Bool = false,
        editPanel: EditHomePanel = .library,
        catalog: CatalogNavigation = CatalogNavigation(),
        preferencesSection: PreferencesSection = .appearance,
        focusedOrigin: AppShellPage? = nil
    ) {
        self.page = page
        self.homeScroll = homeScroll
        self.searchQuery = searchQuery
        self.isEditingHome = isEditingHome
        self.editPanel = editPanel
        self.catalog = catalog
        self.preferencesSection = preferencesSection
        self.focusedOrigin = focusedOrigin
    }

    public static func freshHome() -> AppNavigation {
        AppNavigation()
    }
}

public enum AppShellSession: Equatable, Sendable {
    case hidden
    case visible(AppNavigation)
}

public func appShellControlEffect(page: AppShellPage, control: AppShellControl) -> AppShellControlEffect {
    switch control {
    case .clickOutside:
        page == .focusedAddon ? .followCommandDismissPolicy : .ignore
    case .searchBackdrop:
        page == .search ? .closeSearchRestoreHome : .noOp
    case .invokeHotkey:
        switch page {
        case .home:
            .hideAndClearRouteStack
        case .search:
            .closeSearchRestoreHome
        case .editHome:
            .exitEditHome
        case .catalog, .preferences, .focusedAddon:
            .goHome
        }
    case .escape, .commandW:
        switch page {
        case .home:
            .hideAndClearRouteStack
        case .search:
            .closeSearchRestoreHome
        case .editHome:
            .exitEditHome
        case .catalog:
            .popDetailOrGoHome
        case .preferences:
            .goHome
        case .focusedAddon:
            .popFocusedAddon
        }
    }
}

public func applyAppShellControl(_ control: AppShellControl, to session: AppShellSession) -> AppShellSession {
    switch session {
    case .hidden:
        control == .invokeHotkey ? .visible(.freshHome()) : .hidden
    case let .visible(navigation):
        apply(appShellControlEffect(page: navigation.page, control: control), to: navigation)
    }
}

private func apply(_ effect: AppShellControlEffect, to navigation: AppNavigation) -> AppShellSession {
    switch effect {
    case .noOp, .ignore, .followCommandDismissPolicy:
        return .visible(navigation)
    case .openFreshHome:
        return .visible(.freshHome())
    case .hideAndClearRouteStack:
        return .hidden
    case .closeSearchRestoreHome:
        var next = navigation
        next.page = .home
        next.searchQuery = ""
        return .visible(next)
    case .exitEditHome:
        var next = navigation
        next.page = .home
        next.isEditingHome = false
        next.editPanel = .library
        return .visible(next)
    case .goHome:
        var next = navigation
        next.page = .home
        next.searchQuery = ""
        next.isEditingHome = false
        next.editPanel = .library
        next.focusedOrigin = nil
        return .visible(next)
    case .popDetailOrGoHome:
        guard navigation.catalog.detail != nil else {
            return apply(.goHome, to: navigation)
        }
        var next = navigation
        next.catalog.detail = nil
        next.page = .catalog
        return .visible(next)
    case .popFocusedAddon:
        var next = navigation
        let origin = next.focusedOrigin
        next.focusedOrigin = nil
        if let origin, origin != .focusedAddon {
            next.page = origin
        } else {
            next.page = .home
        }
        return .visible(next)
    }
}
