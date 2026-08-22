import Foundation

public struct AddonRunner: Sendable {
    public var timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 0.8) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func run(
        manifest: AddonManifest,
        addonRoot: URL,
        commandId: String,
        args: [String: JSONValue] = [:],
        context: [String: JSONValue]? = [:],
        timeout: TimeInterval? = nil
    ) throws -> RunResponse {
        let request = RunRequest(
            api: 1,
            op: "run",
            command: commandId,
            args: args,
            context: context
        )
        return try run(
            addonRoot: addonRoot,
            entrypoint: manifest.entrypoint,
            request: request,
            timeout: timeout ?? timeoutSeconds
        )
    }

    public func run(
        addonRoot: URL,
        entrypoint: Entrypoint,
        request: RunRequest,
        timeout: TimeInterval
    ) throws -> RunResponse {
        let entry = addonRoot.appendingPathComponent(entrypoint.path)
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        switch entrypoint.kind {
        case "exec":
            process.executableURL = entry
            process.arguments = []
        case "jxa":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", entry.path]
        case "osascript":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [entry.path]
        default:
            throw AddonRunnerError.unsupportedEntrypointKind(entrypoint.kind)
        }

        process.currentDirectoryURL = addonRoot
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let requestData = try RunJSON.encodeRequest(request)

        try process.run()
        stdin.fileHandleForWriting.write(requestData)
        try stdin.fileHandleForWriting.close()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            throw AddonRunnerError.timeout
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        do {
            return try RunJSON.decodeResponse(stdout: outData)
        } catch {
            if process.terminationStatus != 0 {
                let errText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                return RunResponse(ok: false, error: errText ?? "addon exited \(process.terminationStatus)")
            }
            throw AddonRunnerError.invalidResponse
        }
    }
}

public enum AddonRunnerError: Error, Equatable {
    case unsupportedEntrypointKind(String)
    case timeout
    case invalidResponse
}
