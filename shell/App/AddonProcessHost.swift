import Foundation
import JugnuCore

struct CommandKey: Hashable {
    let addonID: String
    let commandID: String
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

    func tracked() -> [Entry] {
        entries.values.flatMap { $0 }
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
}
