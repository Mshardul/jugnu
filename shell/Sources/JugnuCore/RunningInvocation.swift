import Darwin
import Foundation

public final class RunningInvocation: @unchecked Sendable {
    public let process: Process
    public let markerURL: URL

    private let stdout: Pipe
    private let stderr: Pipe
    private let pid: Int32

    init(process: Process, stdout: Pipe, stderr: Pipe, markerURL: URL) {
        self.process = process
        self.stdout = stdout
        self.stderr = stderr
        self.markerURL = markerURL
        self.pid = process.processIdentifier
    }

    public func waitForResponse(timeout: TimeInterval? = nil) async throws -> RunResponse {
        let work = Task.detached(priority: .userInitiated) { [weak self] () throws -> RunResponse in
            guard let self else { throw AddonRunnerError.invalidResponse }
            return try self.waitForResponseSync(timeout: timeout ?? .infinity)
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            self.terminate()
            work.cancel()
        }
    }

    func waitForResponseSync(timeout: TimeInterval) throws -> RunResponse {
        let group = DispatchGroup()
        group.enter()
        let outBox = DataBox()
        DispatchQueue.global().async { [stdout] in
            outBox.data = stdout.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let waitResult = timeout.isFinite
            ? group.wait(timeout: .now() + timeout)
            : { group.wait(); return DispatchTimeoutResult.success }()
        if waitResult == .timedOut {
            terminate()
            throw AddonRunnerError.timeout
        }
        process.waitUntilExit()
        let outData = outBox.data
        do {
            return try RunJSON.decodeResponse(stdout: outData)
        } catch {
            if process.terminationStatus != 0 {
                let errText = String(
                    data: stderr.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )
                return RunResponse(ok: false, error: errText ?? "addon exited \(process.terminationStatus)")
            }
            throw AddonRunnerError.invalidResponse
        }
    }

    public func terminate() {
        guard process.isRunning else { return }
        kill(pid, SIGTERM)
        let pid = self.pid
        let grace = DispatchTime.now() + .milliseconds(LatencyBudgets.killGraceMs)
        DispatchQueue.global().asyncAfter(deadline: grace) { [weak process] in
            if process?.isRunning == true {
                kill(pid, SIGKILL)
            }
        }
    }

    public func killImmediately() {
        guard process.isRunning else { return }
        kill(pid, SIGKILL)
        process.waitUntilExit()
    }

    public func waitForJobResponse(
        handshakeWindow: TimeInterval = TimeInterval(LatencyBudgets.jobHandshakeWindowMs) / 1000,
        heartbeatWindow: TimeInterval = TimeInterval(LatencyBudgets.jobHeartbeatWindowMs) / 1000
    ) async throws -> RunResponse {
        let work = Task.detached(priority: .userInitiated) { [weak self] () throws -> RunResponse in
            guard let self else { throw AddonRunnerError.invalidResponse }
            return try self.waitForJobResponseSync(
                handshakeWindow: handshakeWindow,
                heartbeatWindow: heartbeatWindow
            )
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            self.terminate()
            work.cancel()
        }
    }

    func waitForJobResponseSync(
        handshakeWindow: TimeInterval,
        heartbeatWindow: TimeInterval
    ) throws -> RunResponse {
        let fd = stdout.fileHandleForReading.fileDescriptor
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var collected = Data()
        var sawOutput = false
        let start = Date()
        var last = start

        while true {
            if Task.isCancelled {
                terminate()
                throw CancellationError()
            }

            var buf = [UInt8](repeating: 0, count: 4096)
            let n = buf.withUnsafeMutableBytes { ptr in
                guard let base = ptr.baseAddress else { return ssize_t(-1) }
                return read(fd, base, ptr.count)
            }
            if n > 0 {
                collected.append(contentsOf: buf.prefix(Int(n)))
                sawOutput = true
                last = Date()
            } else if n == 0, !process.isRunning {
                process.waitUntilExit()
                return try finishJobStdout(collected, sawOutput: sawOutput)
            }

            let now = Date()
            if !process.isRunning {
                drainNonblocking(fd: fd, into: &collected, sawOutput: &sawOutput)
                return try finishJobStdout(collected, sawOutput: sawOutput)
            }
            if !sawOutput, now.timeIntervalSince(start) > handshakeWindow {
                killImmediately()
                throw AddonRunnerError.jobHandshakeTimeout
            }
            if sawOutput, now.timeIntervalSince(last) > heartbeatWindow {
                killImmediately()
                throw AddonRunnerError.jobUnresponsive
            }
            usleep(20_000)
        }
    }

    private func drainNonblocking(fd: Int32, into collected: inout Data, sawOutput: inout Bool) {
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = buf.withUnsafeMutableBytes { ptr in
                guard let base = ptr.baseAddress else { return ssize_t(0) }
                return read(fd, base, ptr.count)
            }
            if n > 0 {
                collected.append(contentsOf: buf.prefix(Int(n)))
                sawOutput = true
            } else {
                break
            }
        }
    }

    private func finishJobStdout(_ collected: Data, sawOutput: Bool) throws -> RunResponse {
        do {
            return try RunJSON.decodeResponse(stdout: collected)
        } catch {
            if !sawOutput {
                throw AddonRunnerError.jobHandshakeTimeout
            }
            throw AddonRunnerError.invalidResponse
        }
    }
}

final class DataBox: @unchecked Sendable {
    var data = Data()
}
