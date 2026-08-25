import Foundation

public enum ClockStoreError: Error, Equatable {
    case invalidSelector
    case invalidTimer
    case invalidSnooze
    case timerNotFound(String)
}

public final class ClockStore {
    private struct State: Codable {
        var timers: [ClockTimer]
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func upsert(_ timer: ClockTimer) throws {
        guard isValid(timer) else {
            throw ClockStoreError.invalidTimer
        }
        var state = try load()
        if let index = state.timers.firstIndex(where: { $0.id == timer.id }) {
            state.timers[index] = timer
        } else {
            state.timers.append(timer)
        }
        try save(state)
    }

    public func cancel(id: String) throws {
        var state = try load()
        state.timers.removeAll { $0.id == id }
        try save(state)
    }

    public func pause(id: String? = nil, group: String? = nil) throws {
        try setPaused(true, id: id, group: group)
    }

    public func resume(id: String? = nil, group: String? = nil) throws {
        try setPaused(false, id: id, group: group)
    }

    public func list() throws -> [ClockTimer] {
        try load().timers
    }

    public func due(now: Date) throws -> [ClockTimer] {
        try load().timers
            .filter { $0.enabled && !$0.paused && $0.nextFire <= now }
            .sorted {
                if $0.nextFire == $1.nextFire {
                    return $0.id < $1.id
                }
                return $0.nextFire < $1.nextFire
            }
    }

    public func markFired(id: String, now: Date) throws {
        var state = try load()
        guard let index = state.timers.firstIndex(where: { $0.id == id }) else {
            throw ClockStoreError.timerNotFound(id)
        }
        let timer = state.timers[index]
        switch timer.kind {
        case .interval:
            guard let seconds = timer.intervalSeconds, seconds > 0 else {
                throw ClockStoreError.invalidTimer
            }
            state.timers[index] = timer.replacing(nextFire: now.addingTimeInterval(TimeInterval(seconds)))
        case .oneShot:
            state.timers.remove(at: index)
        }
        try save(state)
    }

    public func snooze(id: String, seconds: Int, now: Date) throws {
        guard seconds > 0 else {
            throw ClockStoreError.invalidSnooze
        }
        var state = try load()
        guard let index = state.timers.firstIndex(where: { $0.id == id }) else {
            throw ClockStoreError.timerNotFound(id)
        }
        state.timers[index] = state.timers[index].replacing(
            nextFire: now.addingTimeInterval(TimeInterval(seconds))
        )
        try save(state)
    }

    private func setPaused(_ paused: Bool, id: String?, group: String?) throws {
        guard id != nil || group != nil else {
            throw ClockStoreError.invalidSelector
        }
        var state = try load()
        state.timers = state.timers.map { timer in
            guard timer.id == id || (id == nil && timer.group == group) else {
                return timer
            }
            return timer.replacing(paused: paused)
        }
        try save(state)
    }

    private func isValid(_ timer: ClockTimer) -> Bool {
        guard !timer.id.isEmpty else {
            return false
        }
        switch timer.kind {
        case .interval:
            return timer.intervalSeconds.map { $0 > 0 } ?? false
        case .oneShot:
            return timer.fireAt != nil
        }
    }

    private func load() throws -> State {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return State(timers: [])
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(State.self, from: data)
    }

    private func save(_ state: State) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension ClockTimer {
    func replacing(paused: Bool? = nil, nextFire: Date? = nil) -> ClockTimer {
        ClockTimer(
            id: id,
            kind: kind,
            intervalSeconds: intervalSeconds,
            fireAt: fireAt,
            enabled: enabled,
            paused: paused ?? self.paused,
            nextFire: nextFire ?? self.nextFire,
            group: group,
            target: target
        )
    }
}
