public enum CatalogCardAction: Equatable, Sendable {
    case install
    case update
    case enable
    case open
}

public enum AddonPrimaryAction {
    public static func shouldShowOpen(isInstalled: Bool, isEnabled: Bool, primary: String?) -> Bool {
        isInstalled && isEnabled && primary != nil
    }

    /// Dense Catalog cards show one action. Disable and Uninstall stay on detail.
    public static func catalogCardAction(
        isInstalled: Bool,
        isEnabled: Bool,
        updateAvailable: Bool,
        primary: String?
    ) -> CatalogCardAction? {
        if !isInstalled {
            return .install
        }
        if updateAvailable {
            return .update
        }
        if !isEnabled {
            return .enable
        }
        if primary != nil {
            return .open
        }
        return nil
    }
}
