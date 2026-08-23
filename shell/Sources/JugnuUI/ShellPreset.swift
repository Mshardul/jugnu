import AppKit
import JugnuCore

public enum ShellPreset: String, Equatable, Sendable {
    case launcher
    case catalog
    case settings
    case detail
    case confirm
    case list
    case form

    /// `compactLauncher` only affects `.launcher`; ignored for other cases.
    public func defaultViewType(compactLauncher: Bool) -> ViewType {
        switch self {
        case .launcher: return compactLauncher ? .seek : .palette
        case .catalog: return .grid
        case .settings, .detail: return .rail
        case .confirm: return .ask
        case .list: return .rows
        case .form: return .fields
        }
    }

    public func size(
        compactLauncher: Bool,
        visibleFrame: NSRect = NSRect(x: 0, y: 0, width: 1440, height: 900)
    ) -> NSSize {
        let box = defaultViewType(compactLauncher: compactLauncher).size(in: visibleFrame)
        return NSSize(width: box.width, height: box.height)
    }

    public var hasSidebar: Bool { self == .catalog }
}
