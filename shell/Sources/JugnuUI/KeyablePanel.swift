import AppKit

public class KeyablePanel: NSPanel {
    /// Called on Esc / Cmd+. (AppKit's cancelOperation route). Rebindable per stack top so callers
    /// don't need each hosted content view to implement its own Esc handler.
    public var escHandler: (() -> Void)?

    override public var canBecomeKey: Bool {
        true
    }

    override public func cancelOperation(_: Any?) {
        escHandler?()
    }
}
