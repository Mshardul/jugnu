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
        if spec.modifiers.contains("command") {
            modifiers.insert(.command)
        }
        if spec.modifiers.contains("option") {
            modifiers.insert(.option)
        }
        if spec.modifiers.contains("control") {
            modifiers.insert(.control)
        }
        if spec.modifiers.contains("shift") {
            modifiers.insert(.shift)
        }

        let key: Key? = switch spec.key {
        case "space": .space
        case "return": .return
        case "tab": .tab
        case "escape": .escape
        case "a": .a
        case "b": .b
        case "c": .c
        case "d": .d
        case "e": .e
        case "f": .f
        case "g": .g
        case "h": .h
        case "i": .i
        case "j": .j
        case "k": .k
        case "l": .l
        case "m": .m
        case "n": .n
        case "o": .o
        case "p": .p
        case "q": .q
        case "r": .r
        case "s": .s
        case "t": .t
        case "u": .u
        case "v": .v
        case "w": .w
        case "x": .x
        case "y": .y
        case "z": .z
        default: nil
        }
        guard let key else { return nil }
        return KeyCombo(key: key, modifiers: modifiers)
    }
}
