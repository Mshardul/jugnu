import Foundation

public enum HostedBlock: String, Equatable, Sendable, CaseIterable {
    case convertFile = "convert-file"
    case convertText = "convert-text"

    public static func resolve(addonID: String, commandID: String) -> HostedBlock? {
        guard FirstPartyShellAddons.ids.contains(addonID) else { return nil }
        return HostedBlock(rawValue: commandID)
    }
}

public extension AppNavigation {
    func openingBlock(_ block: HostedBlock) -> AppNavigation {
        var next = self
        if page != .focusedAddon {
            next.focusedOrigin = (page == .search || page == .editHome) ? .home : page
        }
        next.page = .focusedAddon
        next.block = block
        next.searchQuery = ""
        next.isEditingHome = false
        next.editPanel = .library
        return next
    }
}
