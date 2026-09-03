import Darwin
import Foundation
import JugnuCore

struct ProcessProbe {
    var isAlive: (Int32) -> Bool
    var commName: (Int32) -> String?
    var startTS: (Int32) -> Double?

    static let live = ProcessProbe(
        isAlive: { kill($0, 0) == 0 },
        commName: { pid in
            var buf = [CChar](repeating: 0, count: 256)
            let n = proc_name(pid, &buf, UInt32(buf.count))
            guard n > 0 else { return nil }
            return String(cString: buf)
        },
        startTS: { ShellIdentity.startTS(pid: $0) }
    )

    func isLiveJugnu(pid: Int32, startTS expected: Double) -> Bool {
        guard isAlive(pid) else { return false }
        guard let comm = commName(pid), comm.caseInsensitiveCompare("Jugnu") == .orderedSame else {
            return false
        }
        guard let actual = startTS(pid) else { return false }
        return abs(actual - expected) < 0.05
    }

    func isJugnuComm(_ pid: Int32) -> Bool {
        guard let comm = commName(pid) else { return false }
        return comm.caseInsensitiveCompare("Jugnu") == .orderedSame
    }
}

enum ReaperMode {
    case normal
    case degraded
}

@MainActor
final class AddonReaper {
    var probe: ProcessProbe
    var killGraceMs: Int
    var signal: (Int32, Int32) -> Void

    private let paths: JugnuPaths
    private let host: AddonProcessHost?
    private let log: LifecycleLog?

    init(
        paths: JugnuPaths,
        host: AddonProcessHost? = nil,
        log: LifecycleLog? = nil,
        probe: ProcessProbe = .live,
        killGraceMs: Int = LatencyBudgets.killGraceMs
    ) {
        self.paths = paths
        self.host = host
        self.log = log
        self.probe = probe
        self.killGraceMs = killGraceMs
        self.signal = { pid, sig in _ = kill(pid, sig) }
    }

    func reap(mode: ReaperMode) {
        let owned = Set(host?.tracked().compactMap { entry -> Int32? in
            let pid = entry.invocation.process.processIdentifier
            return pid > 0 ? pid : nil
        } ?? [])
        let dir = paths.stateRunDir
        for item in RunMarker.enumerate(in: dir) {
            let markerURL = dir.appendingPathComponent("\(item.pid).json")
            guard let marker = item.marker else {
                try? FileManager.default.removeItem(at: markerURL)
                continue
            }
            if !probe.isAlive(item.pid) {
                try? FileManager.default.removeItem(at: markerURL)
                continue
            }
            if probe.isJugnuComm(item.pid) {
                try? FileManager.default.removeItem(at: markerURL)
                continue
            }
            let ownerAlive = probe.isLiveJugnu(pid: marker.shellPID, startTS: marker.shellStartTS)
            if ownerAlive {
                continue
            }
            if mode == .normal, owned.contains(item.pid) {
                continue
            }
            signal(item.pid, SIGTERM)
            let pid = item.pid
            let grace = killGraceMs
            let sig = signal
            let alive = probe.isAlive
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(grace)) {
                if alive(pid) {
                    sig(pid, SIGKILL)
                }
            }
            log?.recordNow(event: "reap", origin: marker.origin, reason: mode == .degraded ? "degraded" : "orphan")
            try? FileManager.default.removeItem(at: markerURL)
        }
    }
}
