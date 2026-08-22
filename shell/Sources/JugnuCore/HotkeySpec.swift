import Foundation

public struct HotkeySpec: Equatable, Sendable {
    public var key: String
    public var modifiers: Set<String>

    public init(key: String, modifiers: Set<String>) {
        self.key = key
        self.modifiers = modifiers
    }

    public static func parse(_ raw: String) -> HotkeySpec? {
        let parts = raw.lowercased().split(separator: "+").map(String.init)
        guard let keyPart = parts.last else { return nil }

        var modifiers: Set<String> = []
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command": modifiers.insert("command")
            case "opt", "option", "alt": modifiers.insert("option")
            case "ctrl", "control": modifiers.insert("control")
            case "shift": modifiers.insert("shift")
            default: return nil
            }
        }

        let key: String
        switch keyPart {
        case "space": key = "space"
        case "return", "enter": key = "return"
        case "tab": key = "tab"
        case "escape", "esc": key = "escape"
        case "a" ... "z" where keyPart.count == 1: key = keyPart
        default: return nil
        }
        return HotkeySpec(key: key, modifiers: modifiers)
    }
}
