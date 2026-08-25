import Foundation

public protocol ClockServicing: Sendable {
    func due(now: Date) throws -> [ClockTimer]
    func markFired(id: String, now: Date) throws
}

@MainActor
public final class ClockHost {
    public static let pollInterval: TimeInterval = 2

    private let service: any ClockServicing
    private let onError: (String) -> Void
    private var failedTimerIDs: Set<String> = []
    private var pendingMarkIDs: Set<String> = []
    private var timer: Timer?
    private var inFlightTask: Task<Void, Never>?
    private var isTicking = false

    public init(
        service: any ClockServicing,
        onError: @escaping (String) -> Void = { _ in }
    ) {
        self.service = service
        self.onError = onError
    }

    public convenience init(
        paths: JugnuPaths = JugnuPaths(),
        onError: @escaping (String) -> Void = { _ in }
    ) {
        self.init(service: ClockService(client: ClockClient(paths: paths)), onError: onError)
    }

    public func start(
        invoke: @escaping (
            _ addon: String,
            _ command: String,
            _ timerID: String
        ) async throws -> Void
    ) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.beginTick(invoke: invoke)
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        inFlightTask?.cancel()
    }

    public func tick(
        now: Date,
        invoke: (
            _ addon: String,
            _ command: String,
            _ timerID: String
        ) async throws -> Void
    ) async {
        guard !isTicking else { return }
        isTicking = true
        defer { isTicking = false }

        let dueTimers: [ClockTimer]
        do {
            dueTimers = try service.due(now: now)
        } catch {
            onError("Clock command failed.")
            return
        }

        for dueTimer in dueTimers where dueTimer.enabled && !dueTimer.paused {
            if pendingMarkIDs.contains(dueTimer.id) {
                markConsumed(dueTimer, now: now)
                continue
            }

            do {
                try await invoke(
                    dueTimer.target.addon,
                    dueTimer.target.command,
                    dueTimer.id
                )
                failedTimerIDs.remove(dueTimer.id)
                pendingMarkIDs.insert(dueTimer.id)
                markConsumed(dueTimer, now: now)
            } catch is CancellationError {
                return
            } catch {
                onError("Clock command failed.")
                if failedTimerIDs.contains(dueTimer.id) {
                    // Leave one failed invocation due for a retry, then consume it to avoid a hot loop.
                    failedTimerIDs.remove(dueTimer.id)
                    pendingMarkIDs.insert(dueTimer.id)
                    markConsumed(dueTimer, now: now)
                } else {
                    failedTimerIDs.insert(dueTimer.id)
                }
            }
        }
    }

    private func beginTick(
        invoke: @escaping (
            _ addon: String,
            _ command: String,
            _ timerID: String
        ) async throws -> Void
    ) {
        guard inFlightTask == nil else { return }
        inFlightTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await tick(now: Date(), invoke: invoke)
            inFlightTask = nil
        }
    }

    private func markConsumed(_ timer: ClockTimer, now: Date) {
        do {
            try service.markFired(id: timer.id, now: now)
            pendingMarkIDs.remove(timer.id)
        } catch {
            onError("Clock command failed.")
        }
    }
}
