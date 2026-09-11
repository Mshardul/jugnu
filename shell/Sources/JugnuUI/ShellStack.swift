import Foundation

public enum AddonDetailTab: String, Equatable, Sendable {
    case overview
    case commands
    case settings
}

public enum ShellViewState: Equatable, Sendable {
    case launcher(query: String, selection: String?, scroll: CGFloat)
    case catalog(
        category: String?,
        subcategory: String?,
        tags: Set<String>,
        query: String,
        scroll: CGFloat,
        selectedCardID: String?
    )
    case settings(scroll: CGFloat, focusedControlID: String?)
    case detail(addonID: String, tab: AddonDetailTab = .overview)
    case confirm
    case list(query: String, highlightedID: String?, scroll: CGFloat)
    case form(values: [String: String], focusedFieldID: String?)

    public var preset: ShellPreset {
        switch self {
        case .launcher: .launcher
        case .catalog: .catalog
        case .settings: .settings
        case .detail: .detail
        case .confirm: .confirm
        case .list: .list
        case .form: .form
        }
    }
}

public struct ShellStackEntry: Equatable, Sendable {
    public var state: ShellViewState

    public init(_ state: ShellViewState) {
        self.state = state
    }

    public var preset: ShellPreset {
        state.preset
    }
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

    public var isAtRoot: Bool {
        entries.count == 1
    }

    // re-push of the same preset updates the top entry's state in place instead of stacking
    public mutating func push(_ entry: ShellStackEntry) {
        if let lastIndex = entries.indices.last, entries[lastIndex].preset == entry.preset {
            entries[lastIndex] = entry
            return
        }
        entries.append(entry)
    }

    public mutating func replace(_ entry: ShellStackEntry) {
        guard !entries.isEmpty else {
            entries = [entry]
            return
        }
        entries[entries.count - 1] = entry
    }

    public mutating func pop() {
        guard entries.count > 1 else { return }
        entries.removeLast()
    }

    public mutating func home(initial: ShellViewState) {
        entries = [ShellStackEntry(initial)]
    }

    // leaves the stack empty; do not call top/isAtRoot until home or a fresh push
    public mutating func clear() {
        entries = []
    }
}

public enum InvokeOutcome: Equatable, Sendable {
    case showHome
    case close
}

public func decideInvokeOutcome(stack: ShellStack, isVisible: Bool) -> InvokeOutcome {
    guard isVisible else { return .showHome }
    return stack.top.preset == .launcher ? .close : .showHome
}
