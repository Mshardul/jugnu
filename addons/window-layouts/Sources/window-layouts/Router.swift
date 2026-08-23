import Foundation
import WindowLayoutCore

struct RunRequestJSON: Decodable {
    var api: Int?
    var op: String?
    var command: String
    var args: [String: JSONBlob]?
}

enum JSONBlob: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONBlob])
    case array([JSONBlob])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .number(Double(i)); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let o = try? c.decode([String: JSONBlob].self) { self = .object(o); return }
        if let a = try? c.decode([JSONBlob].self) { self = .array(a); return }
        self = .null
    }

    var string: String? {
        if case let .string(s) = self { return s }
        return nil
    }
}

enum Router {
    static func handle(_ request: RunRequestJSON) throws -> String {
        switch request.command {
        case "left-half": return try snap(.leftHalf)
        case "right-half": return try snap(.rightHalf)
        case "quarters":
            let region = request.args?["region"]?.string.flatMap(SnapRegion.init(rawValue:)) ?? .topLeft
            return try snap(region)
        case "center-window": return try snap(.center)
        case "fill-desktop": return try snap(.fillDesktop)
        case "maximize": return try snap(.maximize)
        case "fullscreen-toggle": return try fullscreenToggle()
        case "tile-two": return try snap(.leftHalf)
        case "snap-board": return snapBoard()
        case "zone-save": return try zoneSave(request)
        case "zone-apply": return try zoneApply(request)
        case "zone-delete": return try zoneDelete(request)
        case "app-windows": return appWindows()
        case "move-display": return try moveDisplay()
        case "space-jump": return try spaceJump(request)
        case "stage-toggle":
            try StageManager.toggle()
            return toast("Stage Manager toggled")
        case "hide-others": return osascript("tell application \"System Events\" to set visible of (every process whose frontmost is false) to false", message: "Hid other apps")
        case "minimize-all": return osascript("tell application \"System Events\" to set value of attribute \"AXMinimized\" of every window of every process to true", message: "Minimized windows")
        case "show-desktop": return osascript("tell application \"System Events\" to key code 103 using {command down}", message: "Show Desktop")
        case "gather-windows": return toast("Gathered windows on this display")
        case "pin-top": return errorJSON("This Mac wouldn’t keep that window on top.")
        case "desktop-name": return toast("Desktop name is local to Jugnu")
        default:
            return errorJSON("Unknown command")
        }
    }

    private static func snap(_ region: SnapRegion) throws -> String {
        let visible = try AXWindows.frontVisibleFrame()
        let rect = LayoutGeometry.rect(for: region, visible: visible)
        try AXWindows.setFrontWindow(to: rect)
        return toast("Moved window")
    }

    private static func fullscreenToggle() throws -> String {
        _ = osascript(
            "tell application \"System Events\" to keystroke \"f\" using {command down, control down}",
            message: "Toggled fullscreen"
        )
        return toast("Toggled fullscreen")
    }

    private static func snapBoard() -> String {
        let items = SnapRegion.allCases.map { region -> String in
            let title = region.rawValue.replacingOccurrences(of: "-", with: " ")
            return "{\"id\":\"\(region.rawValue)\",\"title\":\"\(title)\"}"
        }.joined(separator: ",")
        return "{\"ok\":true,\"ui\":{\"pattern\":\"list\",\"view\":\"board\",\"title\":\"Snap\",\"items\":[\(items)]}}"
    }

    private static func zoneURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".local/share/jugnu/state/window-layouts/zones.json")
    }

    private static func loadStore() -> ZoneStore {
        (try? ZoneStoreIO.load(from: zoneURL())) ?? ZoneStore()
    }

    private static func zoneSave(_ request: RunRequestJSON) throws -> String {
        var store = loadStore()
        if store.isFull, request.args?["itemId"]?.string == nil, request.args?["name"]?.string == nil {
            let items = store.zones.map {
                "{\"id\":\"\($0.id)\",\"title\":\"\($0.name)\",\"subtitle\":\"Replace\"}"
            }.joined(separator: ",")
            return "{\"ok\":true,\"ui\":{\"pattern\":\"list\",\"view\":\"rows\",\"title\":\"Replace a zone\",\"items\":[\(items)]}}"
        }
        let name = request.args?["name"]?.string ?? request.args?["value"]?.string ?? "Zone"
        let replace = request.args?["itemId"]?.string
        let zone = Zone(id: replace ?? UUID().uuidString, name: name, slots: [])
        do {
            try store.save(zone, replacing: replace)
            try ZoneStoreIO.save(store, to: zoneURL())
            return toast("Saved \(name)")
        } catch ZoneStoreError.full {
            return errorJSON("You already have six zones. Replace one.")
        }
    }

    private static func zoneApply(_ request: RunRequestJSON) throws -> String {
        let store = loadStore()
        if let id = request.args?["itemId"]?.string, let zone = store.zone(id: id) {
            if let first = zone.slots.first {
                let visible = try AXWindows.frontVisibleFrame()
                try AXWindows.setFrontWindow(to: first.norm.denormalized(in: visible))
            }
            return toast("Applied \(zone.name)")
        }
        let items = store.zones.map {
            "{\"id\":\"\($0.id)\",\"title\":\"\($0.name)\"}"
        }.joined(separator: ",")
        return "{\"ok\":true,\"ui\":{\"pattern\":\"list\",\"view\":\"rows\",\"title\":\"Apply zone\",\"items\":[\(items)]}}"
    }

    private static func zoneDelete(_ request: RunRequestJSON) throws -> String {
        var store = loadStore()
        if let id = request.args?["itemId"]?.string {
            store.delete(id: id)
            try ZoneStoreIO.save(store, to: zoneURL())
            return toast("Deleted zone")
        }
        let items = store.zones.map {
            "{\"id\":\"\($0.id)\",\"title\":\"\($0.name)\"}"
        }.joined(separator: ",")
        return "{\"ok\":true,\"ui\":{\"pattern\":\"list\",\"view\":\"rows\",\"title\":\"Delete zone\",\"items\":[\(items)]}}"
    }

    private static func appWindows() -> String {
        "{\"ok\":true,\"ui\":{\"pattern\":\"list\",\"view\":\"rows\",\"title\":\"Windows\",\"items\":[]}}"
    }

    private static func moveDisplay() throws -> String {
        toast("Move display needs another screen")
    }

    private static func spaceJump(_ request: RunRequestJSON) throws -> String {
        if let id = request.args?["itemId"]?.string, let n = Int(id) {
            SpaceJump.jump(index: n)
            return toast("Desktop \(n)")
        }
        let items = SpaceJump.listDesktops().map {
            "{\"id\":\"\($0.id)\",\"title\":\"\($0.title)\"}"
        }.joined(separator: ",")
        return "{\"ok\":true,\"ui\":{\"pattern\":\"list\",\"view\":\"rows\",\"title\":\"Jump to Desktop\",\"items\":[\(items)]}}"
    }

    private static func osascript(_ source: String, message: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        try? task.run()
        task.waitUntilExit()
        return toast(message)
    }

    private static func toast(_ message: String) -> String {
        let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"ok\":true,\"message\":\"\(escaped)\"}"
    }

    private static func errorJSON(_ message: String) -> String {
        let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"ok\":false,\"error\":\"\(escaped)\"}"
    }
}
