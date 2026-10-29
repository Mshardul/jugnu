import AppKit

public class KeyablePanel: NSPanel {
    /// rebound per stack top so hosted content views don't each implement Esc
    public var escHandler: (() -> Void)?
    public var commandWHandler: (() -> Void)?

    override public var canBecomeKey: Bool {
        true
    }

    override public func cancelOperation(_: Any?) {
        escHandler?()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandW = flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && event.charactersIgnoringModifiers?.lowercased() == "w"
        if isCommandW {
            commandWHandler?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
