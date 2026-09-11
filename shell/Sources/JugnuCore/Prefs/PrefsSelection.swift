public enum PrefsSelection: String, CaseIterable, Equatable, Sendable {
    case theme
    case addonsInstalled
    case addonsUpdates
    case general

    public static let `default`: PrefsSelection = .theme
}
