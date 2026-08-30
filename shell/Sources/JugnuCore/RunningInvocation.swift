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
        process.terminate()
        let pid = self.pid
        let grace = DispatchTime.now() + .milliseconds(LatencyBudgets.killGraceMs)
        DispatchQueue.global().asyncAfter(deadline: grace) { [weak process] in
            if process?.isRunning == true {
                kill(pid, SIGKILL)
            }
        }
    }
}

final class DataBox: @unchecked Sendable {
    var data = Data()
}
