import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import WindowLayoutCore

enum AXFailure: Error {
    case notTrusted
    case noFrontWindow
    case setFailed
}

struct ManagedWindow {
    var number: CGWindowID
    var title: String
    var pid: pid_t
    var frame: CGRect
    var displayUUID: String
    var visible: CGRect
}

enum AXWindows {
    static func ensureTrusted() throws {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [prompt: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            throw AXFailure.notTrusted
        }
    }

    static func setFrontWindow(to rect: CGRect) throws {
        try ensureTrusted()
        try setFrame(try focusedWindow(), cocoa: rect)
    }

    static func frontVisibleFrame() throws -> CGRect {
        try ensureTrusted()
        return screen(for: try cocoaFrame(of: try focusedWindow())).visibleFrame
    }

    static func onscreenWindows() throws -> [ManagedWindow] {
        try ensureTrusted()
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var result: [ManagedWindow] = []
        for entry in info {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let number = entry[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t else { continue }
            guard let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let cg = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            guard cg.width >= 80, cg.height >= 80 else { continue }
            let cocoa = cocoaRect(fromCGWindow: cg)
            let scr = screen(for: cocoa)
            let title = entry[kCGWindowName as String] as? String ?? "Window"
            result.append(
                ManagedWindow(
                    number: number,
                    title: title,
                    pid: pid,
                    frame: cocoa,
                    displayUUID: displayUUID(for: scr),
                    visible: scr.visibleFrame
                )
            )
        }
        return result
    }

    static func liveWindows() throws -> [LiveWindow] {
        try onscreenWindows().map {
            LiveWindow(frame: $0.frame, displayUUID: $0.displayUUID, visible: $0.visible)
        }
    }

    static func setWindow(number: CGWindowID, to cocoa: CGRect) throws {
        try ensureTrusted()
        try setFrame(try axWindow(number: number), cocoa: cocoa)
    }

    static func tileTwo(swap: Bool) throws {
        let windows = try onscreenWindows()
        guard windows.count >= 2 else { throw AXFailure.noFrontWindow }
        let visible = windows[0].visible
        let pair = LayoutGeometry.tileTwo(front: windows[0].frame, other: windows[1].frame, visible: visible, swap: swap)
        try setWindow(number: windows[0].number, to: pair.0)
        try setWindow(number: windows[1].number, to: pair.1)
    }

    static func moveFrontToNextDisplay() throws {
        let windows = try onscreenWindows()
        guard let front = windows.first else { throw AXFailure.noFrontWindow }
        let screens = NSScreen.screens
        guard screens.count >= 2 else { throw AXFailure.setFailed }
        let current = screen(for: front.frame)
        let idx = screens.firstIndex(where: { $0 === current }) ?? 0
        let next = screens[(idx + 1) % screens.count]
        let dest = LayoutGeometry.rect(for: .fillDesktop, visible: next.visibleFrame)
        try setWindow(number: front.number, to: dest)
    }

    static func gatherFrontApp() throws {
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let windows = try onscreenWindows().filter { $0.pid == frontPID }
        guard let first = windows.first else { throw AXFailure.noFrontWindow }
        let visible = first.visible
        for (offset, window) in windows.enumerated() {
            var frame = visible
            frame.origin.x += CGFloat(offset) * 24
            frame.origin.y += CGFloat(offset) * 24
            frame.size.width = max(visible.width - 80, visible.width * 0.7)
            frame.size.height = max(visible.height - 80, visible.height * 0.7)
            try setWindow(number: window.number, to: frame)
        }
    }

    static func apply(slots: [ZoneSlot]) throws -> [String] {
        let windows = try onscreenWindows()
        var missing: [String] = []
        for (index, slot) in slots.enumerated() {
            guard index < windows.count else { break }
            let target = screenMatching(slot) ?? NSScreen.main
            guard let target else { continue }
            if displayUUID(for: target) != slot.displayUUID {
                missing.append(slot.displayUUID)
            }
            try setWindow(number: windows[index].number, to: slot.norm.denormalized(in: target.visibleFrame))
        }
        return missing
    }

    static func focus(number: CGWindowID) throws {
        try ensureTrusted()
        let window = try axWindow(number: number)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if let pid = try onscreenWindows().first(where: { $0.number == number })?.pid,
           let app = NSRunningApplication(processIdentifier: pid)
        {
            app.activate()
        }
    }

    static func frontWindowNumber() throws -> CGWindowID {
        guard let first = try onscreenWindows().first else { throw AXFailure.noFrontWindow }
        return first.number
    }

    static func frontAppWindows() throws -> [ManagedWindow] {
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return try onscreenWindows().filter { $0.pid == pid }
    }

    private static func focusedWindow() throws -> AXUIElement {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &focused) == .success,
              let app = focused
        else {
            throw AXFailure.noFrontWindow
        }
        let appEl = unsafeBitCast(app, to: AXUIElement.self)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowObj = windowRef
        else {
            throw AXFailure.noFrontWindow
        }
        return unsafeBitCast(windowObj, to: AXUIElement.self)
    }

    private static func axWindow(number: CGWindowID) throws -> AXUIElement {
        let windows = try onscreenWindows()
        guard let match = windows.first(where: { $0.number == number }) else { throw AXFailure.noFrontWindow }
        let app = AXUIElementCreateApplication(match.pid)
        var listRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &listRef) == .success,
              let list = listRef as? [AXUIElement]
        else {
            throw AXFailure.noFrontWindow
        }
        for element in list {
            var ident: CGWindowID = 0
            if axWindowIdentifier(element, &ident) == 0, ident == number {
                return element
            }
        }
        return try focusedWindow()
    }

    private static func setFrame(_ window: AXUIElement, cocoa: CGRect) throws {
        let app = appElement(for: window)
        setEnhancedUI(app, enabled: false)
        defer { setEnhancedUI(app, enabled: true) }
        let ax = axRect(fromCocoa: cocoa)
        var origin = CGPoint(x: ax.origin.x, y: ax.origin.y)
        var size = CGSize(width: ax.size.width, height: ax.size.height)
        guard let pos = AXValueCreate(.cgPoint, &origin),
              let sz = AXValueCreate(.cgSize, &size)
        else {
            throw AXFailure.setFailed
        }
        let p = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        let s = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        guard p == .success, s == .success else { throw AXFailure.setFailed }
    }

    private static func cocoaFrame(of window: AXUIElement) throws -> CGRect {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef
        else {
            throw AXFailure.noFrontWindow
        }
        var origin = CGPoint.zero
        var size = CGSize.zero
        let posAX = unsafeBitCast(posVal, to: AXValue.self)
        let sizeAX = unsafeBitCast(sizeVal, to: AXValue.self)
        AXValueGetValue(posAX, .cgPoint, &origin)
        AXValueGetValue(sizeAX, .cgSize, &size)
        return cocoaRect(fromCGWindow: CGRect(origin: origin, size: size))
    }

    private static func appElement(for window: AXUIElement) -> AXUIElement {
        var parent: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &parent) == .success, let parent {
            return unsafeBitCast(parent, to: AXUIElement.self)
        }
        return AXUIElementCreateSystemWide()
    }

    private static func setEnhancedUI(_ app: AXUIElement, enabled: Bool) {
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, enabled as CFBoolean)
    }

    private static func screen(for rect: CGRect) -> NSScreen {
        NSScreen.screens.max(by: { $0.frame.intersection(rect).area < $1.frame.intersection(rect).area })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private static func screenMatching(_ slot: ZoneSlot) -> NSScreen? {
        if let byUUID = NSScreen.screens.first(where: { displayUUID(for: $0) == slot.displayUUID }) {
            return byUUID
        }
        return NSScreen.screens.first(where: {
            abs($0.visibleFrame.width - slot.fingerprint.width) < 2
                && abs($0.visibleFrame.height - slot.fingerprint.height) < 2
        })
    }

    private static func displayUUID(for screen: NSScreen) -> String {
        let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        if let cf = CGDisplayCreateUUIDFromDisplayID(num)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, cf) as String
        }
        return "display-\(num)"
    }

    private static func cocoaRect(fromCGWindow rect: CGRect) -> CGRect {
        let main = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? NSScreen.screens[0]
        let y = main.frame.maxY - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: y, width: rect.width, height: rect.height)
    }

    private static func axRect(fromCocoa rect: CGRect) -> CGRect {
        let main = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? NSScreen.screens[0]
        let y = main.frame.maxY - rect.maxY
        return CGRect(x: rect.origin.x, y: y, width: rect.width, height: rect.height)
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}

@_silgen_name("_AXUIElementGetWindow")
private func axWindowIdentifier(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> Int32
