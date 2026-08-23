import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import WindowLayoutCore

enum AXError: Error {
    case notTrusted
    case noFrontWindow
    case setFailed
}

enum AXWindows {
    static func ensureTrusted() throws {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [prompt: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            throw AXError.notTrusted
        }
    }

    static func setFrontWindow(to rect: CGRect) throws {
        try ensureTrusted()
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &focused) == .success,
              let app = focused
        else {
            throw AXError.noFrontWindow
        }
        let appEl = unsafeBitCast(app, to: AXUIElement.self)
        setEnhancedUI(appEl, enabled: false)
        defer { setEnhancedUI(appEl, enabled: true) }

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowObj = windowRef
        else {
            throw AXError.noFrontWindow
        }
        let window = unsafeBitCast(windowObj, to: AXUIElement.self)
        try setFrame(window, rect: rect)
    }

    static func frontVisibleFrame() throws -> CGRect {
        try ensureTrusted()
        guard let screen = NSScreen.main else { throw AXError.noFrontWindow }
        return screen.visibleFrame
    }

    private static func setEnhancedUI(_ app: AXUIElement, enabled: Bool) {
        let attr = "AXEnhancedUserInterface" as CFString
        AXUIElementSetAttributeValue(app, attr, enabled as CFBoolean)
    }

    private static func setFrame(_ window: AXUIElement, rect: CGRect) throws {
        var origin = CGPoint(x: rect.origin.x, y: rect.origin.y)
        var size = CGSize(width: rect.size.width, height: rect.size.height)
        guard let pos = AXValueCreate(.cgPoint, &origin),
              let sz = AXValueCreate(.cgSize, &size)
        else {
            throw AXError.setFailed
        }
        let p = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        let s = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        guard p == .success, s == .success else { throw AXError.setFailed }
    }
}

enum StageManager {
    static func toggle() throws {
        let src = """
        tell application "System Settings" to activate
        """
        _ = src
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.WindowManager", "GloballyEnabled"]
        let out = Pipe()
        task.standardOutput = out
        try task.run()
        task.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        let enabled = raw == "1"
        let write = Process()
        write.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        write.arguments = ["write", "com.apple.WindowManager", "GloballyEnabled", "-int", enabled ? "0" : "1"]
        try write.run()
        write.waitUntilExit()
    }
}

enum SpaceJump {
    static func jump(index: Int) {
        guard (1 ... 9).contains(index) else { return }
        let key: CGKeyCode
        switch index {
        case 1: key = 18
        case 2: key = 19
        case 3: key = 20
        case 4: key = 21
        case 5: key = 23
        case 6: key = 22
        case 7: key = 26
        case 8: key = 28
        case 9: key = 25
        default: return
        }
        post(key: key, flags: .maskControl)
    }

    static func listDesktops() -> [(id: String, title: String)] {
        (1 ... 9).map { ("\($0)", "Desktop \($0)") }
    }

    private static func post(key: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        down?.flags = flags
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
