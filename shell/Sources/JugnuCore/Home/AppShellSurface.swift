import CoreGraphics
import Foundation

public struct AppShellSurface: Equatable, Sendable {
    public var frame: CGRect
    public var navigation: AppNavigation

    public init(frame: CGRect, navigation: AppNavigation) {
        self.frame = frame
        self.navigation = navigation
    }
}

public struct AppShellSearchAction: Equatable, Sendable {
    public var addonName: String
    public var actionTitle: String
    public var qualifiedID: String

    public init(addonName: String, actionTitle: String, qualifiedID: String) {
        self.addonName = addonName
        self.actionTitle = actionTitle
        self.qualifiedID = qualifiedID
    }
}

public struct AppShellDestination: Equatable, Sendable {
    public var page: AppShellPage
    public var title: String
    public var keywords: [String]

    public init(page: AppShellPage, title: String, keywords: [String]) {
        self.page = page
        self.title = title
        self.keywords = keywords
    }
}

public enum AppShellSearchRow: Equatable, Sendable {
    case action(AppShellSearchAction)
    case page(AppShellPage, title: String)
}

public struct AppShellSearchActivation: Equatable, Sendable {
    public var qualifiedID: String?
    public var surface: AppShellSurface

    public init(qualifiedID: String?, surface: AppShellSurface) {
        self.qualifiedID = qualifiedID
        self.surface = surface
    }
}

public func appShellDestinations() -> [AppShellDestination] {
    [
        AppShellDestination(
            page: .catalog,
            title: "Catalog",
            keywords: ["browse", "addons", "catalog", "install", "discover"]
        ),
        AppShellDestination(
            page: .preferences,
            title: "Preferences",
            keywords: ["preferences", "settings", "theme", "general"]
        )
    ]
}

public func appShellSearchLabel(addonName: String, actionTitle: String) -> String {
    "\(addonName) › \(actionTitle)"
}

public func appShellSearchRows(actions: [AppShellSearchAction], query: String) -> [AppShellSearchRow] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        let actions = actions.map { AppShellSearchRow.action($0) }
        let pages = appShellDestinations().map { AppShellSearchRow.page($0.page, title: $0.title) }
        return actions + pages
    }
    let matchedActions = actions.compactMap { action -> (AppShellSearchRow, Int)? in
        let score = [
            Fuzzy.score(query: trimmed, in: action.actionTitle),
            Fuzzy.score(query: trimmed, in: action.addonName),
            Fuzzy.score(query: trimmed, in: "\(action.addonName) \(action.actionTitle)")
        ].max() ?? 0
        guard score > 0 else { return nil }
        return (.action(action), score)
    }
    let matchedPages = appShellDestinations().compactMap { destination -> (AppShellSearchRow, Int)? in
        let score = ([destination.title] + destination.keywords)
            .map { Fuzzy.score(query: trimmed, in: $0) }
            .max() ?? 0
        guard score > 0 else { return nil }
        return (.page(destination.page, title: destination.title), score)
    }
    return (matchedActions + matchedPages).sorted { $0.1 > $1.1 }.map(\.0)
}

public func appShellTypeToSearchQuery(_ characters: String) -> String? {
    guard characters.count == 1, let scalar = characters.unicodeScalars.first else { return nil }
    if CharacterSet.whitespacesAndNewlines.contains(scalar) {
        return nil
    }
    if CharacterSet.controlCharacters.contains(scalar) {
        return nil
    }
    return characters
}

public func presentAppShell(
    in visible: CGRect,
    navigation: AppNavigation = .freshHome()
) -> AppShellSurface {
    AppShellSurface(frame: appShellFrame(in: visible), navigation: navigation)
}

public func showAppShellPage(_ page: AppShellPage, on surface: AppShellSurface) -> AppShellSurface {
    var next = surface
    next.navigation.page = page
    if page != .search {
        next.navigation.searchQuery = ""
    }
    return next
}

public func openAppShellSearch(on surface: AppShellSurface, query: String = "") -> AppShellSurface {
    var next = surface
    next.navigation.page = .search
    next.navigation.searchQuery = query
    return next
}

public func appShellSurface(after control: AppShellControl, surface: AppShellSurface) -> AppShellSurface? {
    switch applyAppShellControl(control, to: .visible(surface.navigation)) {
    case .hidden:
        nil
    case let .visible(navigation):
        AppShellSurface(frame: surface.frame, navigation: navigation)
    }
}

public func activateAppShellSearch(
    _ row: AppShellSearchRow,
    on surface: AppShellSurface
) -> AppShellSearchActivation {
    switch row {
    case let .action(action):
        var next = surface
        next.navigation.page = .home
        next.navigation.searchQuery = ""
        return AppShellSearchActivation(qualifiedID: action.qualifiedID, surface: next)
    case let .page(page, _):
        return AppShellSearchActivation(qualifiedID: nil, surface: showAppShellPage(page, on: surface))
    }
}
