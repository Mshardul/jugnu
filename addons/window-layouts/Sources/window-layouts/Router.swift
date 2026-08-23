import CoreGraphics
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
        switch self {
        case let .string(s): return s
        case let .number(n): return String(Int(n))
        default: return nil
        }
    }
}

enum Router {
    static func handle(_ request: RunRequestJSON) throws -> String {
        switch request.command {
        case "left-half": return try snap(.leftHalf)
        case "right-half": return try snap(.rightHalf)
        case "quarters": return try quarters(request)
        case "center-window": return try snap(.center)
        case "fill-desktop": return try snap(.fillDesktop)
        case "maximize": return try snap(.maximize)
        case "fullscreen-toggle": return fullscreenToggle()
        case "tile-two":
            try AXWindows.tileTwo(swap: request.args?["swap"]?.string == "true")
            return ok("Tiled two windows")
        case "snap-board": return try snapBoard(request)
        case "zone-save": return try zoneSave(request)
        case "zone-apply": return try zoneApply(request)
        case "zone-delete": return try zoneDelete(request)
        case "app-windows": return try appWindows(request)
        case "move-display":
            do {
                try AXWindows.moveFrontToNextDisplay()
                return ok("Moved to the other display")
            } catch {
                return fail("That needs another display.")
            }
        case "space-jump": return try spaceJump(request)
        case "stage-toggle":
            try StageManager.toggle()
            return ok("Stage Manager toggled")
        case "hide-others":
            return osascript(
                "tell application \"System Events\" to set visible of (every process whose frontmost is false) to false",
                message: "Hid other apps"
            )
        case "minimize-all":
            return osascript(
                "tell application \"System Events\" to set value of attribute \"AXMinimized\" of every window of every process to true",
                message: "Minimized windows"
            )
        case "show-desktop":
            return osascript(
                "tell application \"System Events\" to key code 103 using {command down}",
                message: "Show Desktop"
            )
        case "gather-windows":
            try AXWindows.gatherFrontApp()
            return ok("Gathered this app’s windows")
        case "pin-top":
            do {
                try IsolatedCGS.pinFront(window: try AXWindows.frontWindowNumber())
                return ok("Pinned on top")
            } catch {
                return fail("This Mac wouldn’t keep that window on top.")
            }
        case "desktop-name":
            return try desktopName(request)
        default:
            return fail("Unknown command")
        }
    }

    private static func snap(_ region: SnapRegion) throws -> String {
        let visible = try AXWindows.frontVisibleFrame()
        try AXWindows.setFrontWindow(to: LayoutGeometry.rect(for: region, visible: visible))
        return ok("Moved window")
    }

    private static func quarters(_ request: RunRequestJSON) throws -> String {
        let raw = request.args?["itemId"]?.string ?? request.args?["region"]?.string
        if let raw, let region = SnapRegion(rawValue: raw) {
            return try snap(region)
        }
        let items = [SnapRegion.topLeft, .topRight, .bottomLeft, .bottomRight].map {
            AddonWireItem(id: $0.rawValue, title: $0.rawValue.replacingOccurrences(of: "-", with: " "))
        }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(pattern: "list", title: "Quarter", items: items, view: "rows")
        )
    }

    private static func snapBoard(_ request: RunRequestJSON) throws -> String {
        if let id = request.args?["itemId"]?.string, let region = SnapRegion(rawValue: id) {
            return try snap(region)
        }
        let items = SnapRegion.allCases.map {
            AddonWireItem(id: $0.rawValue, title: $0.rawValue.replacingOccurrences(of: "-", with: " "))
        }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(pattern: "list", title: "Snap", items: items, view: "board")
        )
    }

    private static func fullscreenToggle() -> String {
        _ = osascript(
            "tell application \"System Events\" to keystroke \"f\" using {command down, control down}",
            message: "Toggled fullscreen"
        )
        return ok("Toggled fullscreen")
    }

    private static func stateDir() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/jugnu/state/window-layouts")
    }

    private static func zoneURL() -> URL { stateDir().appendingPathComponent("zones.json") }
    private static func labelsURL() -> URL { stateDir().appendingPathComponent("labels.json") }

    private static func loadStore() -> ZoneStore {
        (try? ZoneStoreIO.load(from: zoneURL())) ?? ZoneStore()
    }

    private static func loadLabels() -> DesktopLabels {
        (try? DesktopLabelsIO.load(from: labelsURL())) ?? DesktopLabels()
    }

    private static func zoneSave(_ request: RunRequestJSON) throws -> String {
        var store = loadStore()
        let name = request.args?["name"]?.string ?? request.args?["value"]?.string
        let replace = request.args?["itemId"]?.string
        switch ZoneSavePlanner.plan(store: store, name: name, replaceId: replace) {
        case .askName:
            return AddonWire.encode(
                ok: true,
                ui: AddonWireUI(
                    pattern: "form",
                    title: "Save zone",
                    fields: [AddonWireField(id: "name", label: "Name", kind: "text")],
                    view: "fields"
                )
            )
        case let .pickReplacement(zones):
            let items = zones.map { AddonWireItem(id: $0.id, title: $0.name, subtitle: "Replace") }
            return AddonWire.encode(
                ok: true,
                ui: AddonWireUI(pattern: "list", title: "Replace a zone", items: items, view: "rows")
            )
        case let .commit(commitName, replacing):
            let slots = ZoneCapture.slots(from: try AXWindows.liveWindows())
            let zone = Zone(id: replacing ?? UUID().uuidString, name: commitName, slots: slots)
            try store.save(zone, replacing: replacing)
            try ZoneStoreIO.save(store, to: zoneURL())
            return ok("Saved \(commitName)")
        }
    }

    private static func zoneApply(_ request: RunRequestJSON) throws -> String {
        let store = loadStore()
        if let id = request.args?["itemId"]?.string, let zone = store.zone(id: id) {
            let missing = try AXWindows.apply(slots: zone.slots)
            if missing.isEmpty {
                return ok("Applied \(zone.name)")
            }
            return ok("Applied \(zone.name). One display was missing, so those windows used this screen.")
        }
        let items = store.zones.map { AddonWireItem(id: $0.id, title: $0.name) }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(pattern: "list", title: "Apply zone", items: items, view: "rows")
        )
    }

    private static func zoneDelete(_ request: RunRequestJSON) throws -> String {
        var store = loadStore()
        if let id = request.args?["itemId"]?.string {
            store.delete(id: id)
            try ZoneStoreIO.save(store, to: zoneURL())
            return ok("Deleted zone")
        }
        let items = store.zones.map { AddonWireItem(id: $0.id, title: $0.name) }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(pattern: "list", title: "Delete zone", items: items, view: "rows")
        )
    }

    private static func appWindows(_ request: RunRequestJSON) throws -> String {
        if let id = request.args?["itemId"]?.string, let number = CGWindowID(id) {
            try AXWindows.focus(number: number)
            return ok("Focused window")
        }
        let items = try AXWindows.frontAppWindows().map {
            AddonWireItem(id: String($0.number), title: $0.title.isEmpty ? "Window" : $0.title)
        }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(pattern: "list", title: "Windows", items: items, view: "rows")
        )
    }

    private static func spaceJump(_ request: RunRequestJSON) throws -> String {
        if let id = request.args?["itemId"]?.string, let n = Int(id) {
            SpaceJump.jump(index: n)
            return ok("Desktop \(n)")
        }
        let labels = loadLabels()
        let spaces = IsolatedCGS.spaces() ?? (1 ... 9).map {
            IsolatedCGS.SpaceItem(id: "\($0)", index: $0, current: false)
        }
        let items = spaces.map { space in
            let title = labels.bySpaceId[space.id] ?? "Desktop \(space.index)"
            return AddonWireItem(id: String(space.index), title: title)
        }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(pattern: "list", title: "Jump to Desktop", items: items, view: "rows")
        )
    }

    private static func desktopName(_ request: RunRequestJSON) throws -> String {
        let name = request.args?["name"]?.string ?? request.args?["value"]?.string
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var labels = loadLabels()
            labels.bySpaceId[IsolatedCGS.currentSpaceId()] = name
            try DesktopLabelsIO.save(labels, to: labelsURL())
            return ok("Named this Desktop \(name)")
        }
        return AddonWire.encode(
            ok: true,
            ui: AddonWireUI(
                pattern: "form",
                title: "Name this Desktop",
                fields: [AddonWireField(id: "name", label: "Name", kind: "text")],
                view: "fields"
            )
        )
    }

    private static func osascript(_ source: String, message: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        try? task.run()
        task.waitUntilExit()
        return ok(message)
    }

    private static func ok(_ message: String) -> String {
        AddonWire.encode(ok: true, message: message)
    }

    private static func fail(_ message: String) -> String {
        AddonWire.encode(ok: false, error: message)
    }
}
