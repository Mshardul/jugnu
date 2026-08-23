import Foundation

public enum ShellViewState: Equatable, Sendable {
    case launcher(query: String, selection: String?, scroll: CGFloat)
    case catalog(category: String?, subcategory: String?, tags: Set<String>, query: String, scroll: CGFloat, selectedCardID: String?)
    case settings(scroll: CGFloat, focusedControlID: String?)
    case detail(addonID: String)
    case confirm
    case list(query: String, highlightedID: String?, scroll: CGFloat)
    case form(values: [String: String], focusedFieldID: String?)

    public var preset: ShellPreset {
        switch self {
        case .launcher: return .launcher
        case .catalog: return .catalog
        case .settings: return .settings
        case .detail: return .detail
        case .confirm: return .confirm
        case .list: return .list
        case .form: return .form
        }
    }
}

public struct ShellStackEntry: Equatable, Sendable {
    public var state: ShellViewState

    public init(_ state: ShellViewState) {
        self.state = state
    }

    public var preset: ShellPreset { state.preset }
}

public struct ShellStack: Equatable, Sendable {
    public private(set) var entries: [ShellStackEntry]

    public init(root: ShellStackEntry = ShellStackEntry(.launcher(query: "", selection: nil, scroll: 0))) {
        self.entries = [root]
    }

    public var top: ShellStackEntry {
        guard let last = entries.last else {
            preconditionFailure("ShellStack.top read after clear(); call home() or push() first")
        }
        return last
    }

    public var isAtRoot: Bool { entries.count == 1 }

    /// Push a child. No-op (updates the top entry's state in place) if `entry.preset == top.preset` (idempotent rule).
    public mutating func push(_ entry: ShellStackEntry) {
        if let lastIndex = entries.indices.last, entries[lastIndex].preset == entry.preset {
            entries[lastIndex] = entry
            return
        }
        entries.append(entry)
    }

    /// Replace the top entry with a sibling.
    public mutating func replace(_ entry: ShellStackEntry) {
        guard !entries.isEmpty else {
            entries = [entry]
            return
        }
        entries[entries.count - 1] = entry
    }

    /// Pop one entry. No-op if already at root.
    public mutating func pop() {
        guard entries.count > 1 else { return }
        entries.removeLast()
    }

    /// Reset to a fresh `[launcher]` (home).
    public mutating func home(initial: ShellViewState) {
        entries = [ShellStackEntry(initial)]
    }

    /// Empty the stack entirely (dismiss/close). Do not call `top`/`isAtRoot` until `home` or a fresh push.
    public mutating func clear() {
        entries = []
    }
}

public enum InvokeOutcome: Equatable, Sendable {
    case showHome
    case close
}

/// Invoke hotkey / Open Palette decision: not visible or not on launcher -> home; visible and on launcher -> close.
public func decideInvokeOutcome(stack: ShellStack, isVisible: Bool) -> InvokeOutcome {
    guard isVisible else { return .showHome }
    return stack.top.preset == .launcher ? .close : .showHome
}
