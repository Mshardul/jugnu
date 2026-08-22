import AppKit
import HotKey
import JugnuCore

@MainActor
final class HotkeyController {
    private let model: AppModel
    private let onFire: () -> Void
    private var hotKey: HotKey?

    init(model: AppModel, onFire: @escaping () -> Void) {
        self.model = model
        self.onFire = onFire
    }

    func registerFromConfig() {
        hotKey = nil
        guard let combo = Self.parse(model.config.shell.hotkey) else {
            NSLog("Jugnu: could not parse hotkey '%@'", model.config.shell.hotkey)
            return
        }
        let key = HotKey(keyCombo: combo)
        key.keyDownHandler = { [onFire] in
            DispatchQueue.main.async { onFire() }
        }
        hotKey = key
    }

    static func parse(_ raw: String) -> KeyCombo? {
        guard let spec = HotkeySpec.parse(raw) else { return nil }
        var modifiers: NSEvent.ModifierFlags = []
        if spec.modifiers.contains("command") { modifiers.insert(.command) }
        if spec.modifiers.contains("option") { modifiers.insert(.option) }
        if spec.modifiers.contains("control") { modifiers.insert(.control) }
        if spec.modifiers.contains("shift") { modifiers.insert(.shift) }

        let key: Key?
        switch spec.key {
        case "space": key = .space
        case "return": key = .return
        case "tab": key = .tab
        case "escape": key = .escape
        case "a": key = .a
        case "b": key = .b
        case "c": key = .c
        case "d": key = .d
        case "e": key = .e
        case "f": key = .f
        case "g": key = .g
        case "h": key = .h
        case "i": key = .i
        case "j": key = .j
        case "k": key = .k
        case "l": key = .l
        case "m": key = .m
        case "n": key = .n
        case "o": key = .o
        case "p": key = .p
        case "q": key = .q
        case "r": key = .r
        case "s": key = .s
        case "t": key = .t
        case "u": key = .u
        case "v": key = .v
        case "w": key = .w
        case "x": key = .x
        case "y": key = .y
        case "z": key = .z
        default: key = nil
        }
        guard let key else { return nil }
        return KeyCombo(key: key, modifiers: modifiers)
    }
}
