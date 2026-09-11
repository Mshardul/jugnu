public enum AddonPrimaryAction {
    public static func shouldShowOpen(isInstalled: Bool, isEnabled: Bool, primary: String?) -> Bool {
        isInstalled && isEnabled && primary != nil
    }
}
