import CoreGraphics
import Darwin
import Foundation

enum IsolatedCGS {
    enum Failure: Error {
        case refused
    }

    struct SpaceItem {
        var id: String
        var index: Int
        var current: Bool
    }

    static func spaces() -> [SpaceItem]? {
        guard let copy = symbol("CGSCopyManagedDisplaySpaces", as: CGSCopyManagedDisplaySpaces.self),
              let main = symbol("CGSMainConnectionID", as: CGSMainConnectionID.self)
        else {
            return nil
        }
        let cid = main()
        guard let raw = copy(cid) else { return nil }
        let displays = raw as [AnyObject]
        var items: [SpaceItem] = []
        var index = 1
        for display in displays {
            guard let dict = display as? [String: Any] else { continue }
            let currentUUID = ((dict["Current Space"] as? [String: Any])?["uuid"] as? String)
            let spaces = dict["Spaces"] as? [[String: Any]] ?? []
            for space in spaces {
                let uuid = space["uuid"] as? String ?? "\(index)"
                items.append(SpaceItem(id: uuid, index: index, current: uuid == currentUUID))
                index += 1
            }
        }
        return items.isEmpty ? nil : items
    }

    static func currentSpaceId() -> String {
        spaces()?.first(where: \.current)?.id ?? "1"
    }

    static func pinFront(window: CGWindowID) throws {
        guard let main = symbol("CGSMainConnectionID", as: CGSMainConnectionID.self),
              let setLevel = symbol("CGSSetWindowLevel", as: CGSSetWindowLevel.self)
        else {
            throw Failure.refused
        }
        let floating = CGWindowLevelForKey(.floatingWindow)
        let status = setLevel(main(), window, Int32(floating))
        if status != 0 {
            throw Failure.refused
        }
    }

    static func moveFront(window: CGWindowID, toSpaceIndex index: Int) throws {
        guard let main = symbol("CGSMainConnectionID", as: CGSMainConnectionID.self),
              let move = symbol("CGSMoveWorkspaceWindowList", as: CGSMoveWorkspaceWindowList.self)
        else {
            throw Failure.refused
        }
        var wid = window
        let status = move(main(), &wid, 1, Int32(index))
        if status != 0 {
            throw Failure.refused
        }
    }

    private typealias CGSMainConnectionID = @convention(c) () -> UInt32
    private typealias CGSCopyManagedDisplaySpaces = @convention(c) (UInt32) -> NSArray?
    private typealias CGSSetWindowLevel = @convention(c) (UInt32, CGWindowID, Int32) -> Int32
    private typealias CGSMoveWorkspaceWindowList = @convention(c) (UInt32, UnsafeMutablePointer<CGWindowID>, Int32, Int32) -> Int32

    private static func symbol<T>(_ name: String, as _: T.Type) -> T? {
        let handle = name.hasPrefix("CGSCopy")
            ? dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
            : dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        guard handle != nil else { return nil }
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
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

enum StageManager {
    static func toggle() throws {
        let read = Process()
        read.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        read.arguments = ["read", "com.apple.WindowManager", "GloballyEnabled"]
        let out = Pipe()
        read.standardOutput = out
        try read.run()
        read.waitUntilExit()
        let raw = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        let enabled = raw == "1"
        let write = Process()
        write.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        write.arguments = ["write", "com.apple.WindowManager", "GloballyEnabled", "-int", enabled ? "0" : "1"]
        try write.run()
        write.waitUntilExit()
    }
}
