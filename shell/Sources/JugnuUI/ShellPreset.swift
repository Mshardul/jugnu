import AppKit

public enum ShellPreset: String, Equatable, Sendable {
    case launcher
    case catalog
    case settings
    case detail
    case confirm
    case list
    case form

    /// `compactLauncher` only affects `.launcher`; ignored for other cases.
    public func size(compactLauncher: Bool) -> NSSize {
        switch self {
        case .launcher: return compactLauncher ? NSSize(width: 560, height: 120) : NSSize(width: 560, height: 360)
        case .catalog: return NSSize(width: 800, height: 560)
        case .settings: return NSSize(width: 520, height: 560)
        case .detail: return NSSize(width: 560, height: 480)
        case .confirm: return NSSize(width: 380, height: 180)
        case .list: return NSSize(width: 420, height: 360)
        case .form: return NSSize(width: 400, height: 240)
        }
    }

    public var hasSidebar: Bool { self == .catalog }
}
