import Foundation
import JugnuCore

struct CommandKey: Hashable {
    let addonID: String
    let commandID: String
}

enum JobSpawnGate: Equatable {
    case spawn
    case reuse
    case stillStopping
}

@MainActor
final class AddonProcessHost {
    enum Phase {
        case live
        case dying
    }

    struct Entry {
        let invocation: RunningInvocation
        let invocationTask: Task<Void, Never>?
        let lifecycleClass: LifecycleClass
        let startedAt: Date
        let invokeUUID: UUID
        let markerPath: URL
        var phase: Phase
    }

    var killJob: (RunningInvocation) -> Void = { $0.killImmediately() }
    var replaceDeathCeiling: TimeInterval = TimeInterval(LatencyBudgets.replaceDeathCeilingMs) / 1000

    private var entries: [CommandKey: [Entry]] = [:]
    private let log: LifecycleLog?
    private let now: () -> Date

    init(log: LifecycleLog? = nil, now: @escaping () -> Date = { Date() }) {
        self.log = log
        self.now = now
    }

    func register(key: CommandKey, entry: Entry) {
        entries[key, default: []].append(entry)
    }

    func deregister(key: CommandKey, invokeUUID: UUID) {
        guard var list = entries[key] else { return }
        list.removeAll { $0.invokeUUID == invokeUUID }
        if list.isEmpty {
            entries[key] = nil
        } else {
            entries[key] = list
        }
    }

    func hasTracked(key: CommandKey) -> Bool {
        !(entries[key]?.isEmpty ?? true)
    }

    func hasTracked(addonID: String) -> Bool {
        entries.contains { $0.key.addonID == addonID && !$0.value.isEmpty }
    }

    func tracked() -> [Entry] {
        entries.values.flatMap { $0 }
    }

    func hasLiveJob() -> Bool {
        tracked().contains { $0.lifecycleClass == .job && $0.phase == .live }
    }

    func killTracked(key: CommandKey) {
        guard var list = entries[key] else { return }
        for i in list.indices {
            list[i].phase = .dying
            let inv = list[i].invocation
            list[i].invocationTask?.cancel()
            log?.recordNow(event: "kill", origin: list[i].invokeUUID.uuidString, reason: "edge")
            Task.detached { inv.terminate() }
        }
        entries[key] = list
    }

    func killTracked(addonID: String) {
        for key in entries.keys where key.addonID == addonID {
            killTracked(key: key)
        }
    }

    func noteWakeReapPending() {
        log?.recordNow(event: "kill", reason: "wake-reap-stub")
    }

    func killAll() {
        let all = tracked()
        for entry in all {
            entry.invocationTask?.cancel()
            entry.invocation.process.terminate()
        }
        log?.recordNow(event: "kill", reason: "quit")
        let processes = all.map(\.invocation.process)
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(LatencyBudgets.killGraceMs)) {
            for process in processes where process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
    }

    func prepareJobSpawn(key: CommandKey, mode: OnReinvoke, programmatic: Bool) async -> JobSpawnGate {
        let current = entries[key] ?? []
        let blocking = current.filter { $0.lifecycleClass == .job }
        guard !blocking.isEmpty else { return .spawn }

        // Context-triggered / programmatic invoke that collides with a running
        // instance behaves as reuse regardless of on_reinvoke (UI-speed spec §7).
        let effective: OnReinvoke = programmatic ? .reuse : mode

        if blocking.contains(where: { $0.phase == .dying }) {
            if effective == .reuse {
                return .reuse
            }
            return await waitForReplaceSlot(key: key, blocking: blocking)
        }

        if effective == .reuse {
            return .reuse
        }
        return await waitForReplaceSlot(key: key, blocking: blocking)
    }

    private func waitForReplaceSlot(key: CommandKey, blocking: [Entry]) async -> JobSpawnGate {
        for entry in blocking {
            entry.invocationTask?.cancel()
            killJob(entry.invocation)
            log?.recordNow(event: "kill", origin: entry.invokeUUID.uuidString, reason: "replace")
        }
        if var list = entries[key] {
            for i in list.indices where list[i].lifecycleClass == .job {
                list[i].phase = .dying
            }
            entries[key] = list
        }
        let deadline = Date().addingTimeInterval(replaceDeathCeiling)
        while Date() < deadline {
            let still = (entries[key] ?? []).filter {
                $0.lifecycleClass == .job && $0.invocation.process.isRunning
            }
            if still.isEmpty { return .spawn }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let stillAlive = (entries[key] ?? []).contains {
            $0.lifecycleClass == .job && $0.invocation.process.isRunning
        }
        return stillAlive ? .stillStopping : .spawn
    }
}
