import AppKit

public class KeyablePanel: NSPanel {
    // rebound per stack top so hosted content views don't each implement Esc
    public var escHandler: (() -> Void)?

    override public var canBecomeKey: Bool {
        true
    }

    override public func cancelOperation(_: Any?) {
        escHandler?()
    }
}
