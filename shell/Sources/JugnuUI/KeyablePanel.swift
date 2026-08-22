import AppKit

public class KeyablePanel: NSPanel {
    override public var canBecomeKey: Bool { true }
}
