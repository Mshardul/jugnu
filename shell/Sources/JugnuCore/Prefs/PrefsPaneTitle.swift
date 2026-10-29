public enum PrefsPaneTitle {
    public static func title(for selection: PrefsSelection) -> String {
        switch selection {
        case .theme: "Appearance"
        case .addonsInstalled: "Installed"
        case .addonsUpdates: "Updates"
        case .general: "General"
        }
    }
}
