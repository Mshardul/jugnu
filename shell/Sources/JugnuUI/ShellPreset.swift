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
        case .launcher: compactLauncher ? .seek : .palette
        case .catalog: .grid
        case .settings, .detail: .rail
        case .confirm: .ask
        case .list: .rows
        case .form: .fields
        }
    }

    public func size(
        compactLauncher: Bool,
        visibleFrame: NSRect = NSRect(x: 0, y: 0, width: 1440, height: 900)
    ) -> NSSize {
        let box = defaultViewType(compactLauncher: compactLauncher).size(in: visibleFrame)
        return NSSize(width: box.width, height: box.height)
    }

    public var hasSidebar: Bool {
        self == .catalog
    }
}
