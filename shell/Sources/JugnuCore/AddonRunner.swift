import Foundation

public struct AddonRunner: Sendable {
    public var timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 0.8) {
        self.timeoutSeconds = timeoutSeconds
    }

    public struct ShellIdentity: Sendable, Equatable {
        public var pid: Int32
        public var startTS: Double
        public init(pid: Int32, startTS: Double) {
            self.pid = pid
            self.startTS = startTS
        }

        public static let unknown = ShellIdentity(pid: getpid(), startTS: 0)
    }

    public func run(
        manifest: AddonManifest,
        addonRoot: URL,
        commandId: String,
        args: [String: JSONValue] = [:],
        context: [String: JSONValue]? = [:],
        timeout: TimeInterval? = nil,
        paths: JugnuPaths? = nil
    ) throws -> RunResponse {
        let request = RunRequest(
            api: 1,
            op: "run",
            command: commandId,
            args: args,
            context: context
        )
        let extra = try Self.helperEnvironment(manifest: manifest, paths: paths)
        return try run(
            addonRoot: addonRoot,
            entrypoint: manifest.entrypoint,
            request: request,
            timeout: timeout ?? timeoutSeconds,
            extraEnvironment: extra
        )
    }

    public static func helperEnvironment(manifest: AddonManifest, paths: JugnuPaths?) throws -> [String: String] {
        guard !manifest.helpers.isEmpty else { return [:] }
        guard let paths else {
            throw AddonRunnerError.helperMissing("paths")
        }
        var env: [String: String] = [:]
        for ref in manifest.helpers {
            let root = paths.helperRoot(id: ref.id, version: ref.version)
            let yaml = root.appendingPathComponent("helper.yaml")
            guard FileManager.default.fileExists(atPath: yaml.path) else {
                throw AddonRunnerError.helperMissing(ref.id)
            }
            env[ref.environmentVariable] = root.path
        }
        return env
    }

    public func spawn(
        manifest: AddonManifest,
        addonRoot: URL,
        commandId: String,
        args: [String: JSONValue] = [:],
        context: [String: JSONValue]? = [:],
        invokeUUID: UUID = UUID(),
        lifecycleClass: LifecycleClass = .oneshot,
        shellIdentity: ShellIdentity = .unknown,
        markerDir: URL,
        paths: JugnuPaths? = nil
    ) throws -> RunningInvocation {
        let request = RunRequest(
            api: 1,
            op: "run",
            command: commandId,
            args: args,
            context: context
        )
        let extra = try Self.helperEnvironment(manifest: manifest, paths: paths)
        let origin = "\(manifest.id):\(commandId):\(invokeUUID.uuidString)"
        return try spawn(
            addonRoot: addonRoot,
            entrypoint: manifest.entrypoint,
            request: request,
            extraEnvironment: extra,
            origin: origin,
            lifecycleClass: lifecycleClass,
            shellIdentity: shellIdentity,
            markerDir: markerDir
        )
    }

    public func spawn(
        addonRoot: URL,
        entrypoint: Entrypoint,
        request: RunRequest,
        extraEnvironment: [String: String] = [:],
        origin: String = "test:test:test",
        lifecycleClass: LifecycleClass = .oneshot,
        shellIdentity: ShellIdentity = .unknown,
        markerDir: URL
    ) throws -> RunningInvocation {
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

        var env = ProcessInfo.processInfo.environment
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        env["JUGNU_ORIGIN"] = origin
        env["JUGNU_SHELL_START_TS"] = String(shellIdentity.startTS)
        process.environment = env

        let requestData = try RunJSON.encodeRequest(request)

        try process.run()
        let pid = process.processIdentifier

        let marker = RunMarker(
            origin: origin,
            lifecycleClass: lifecycleClass.rawValue,
            shellPID: shellIdentity.pid,
            shellStartTS: shellIdentity.startTS,
            spawnedAt: Date().timeIntervalSince1970
        )
        try? RunMarker.write(marker, pid: pid, to: markerDir)
        let liveMarkerURL = markerDir.appendingPathComponent("\(pid).json")

        process.terminationHandler = { _ in
            RunMarker.delete(pid: pid, in: markerDir)
        }

        stdin.fileHandleForWriting.write(requestData)
        try? stdin.fileHandleForWriting.close()

        return RunningInvocation(
            process: process,
            stdout: stdout,
            stderr: stderr,
            markerURL: liveMarkerURL
        )
    }

    public func run(
        addonRoot: URL,
        entrypoint: Entrypoint,
        request: RunRequest,
        timeout: TimeInterval,
        extraEnvironment: [String: String] = [:]
    ) throws -> RunResponse {
        let markerDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-run-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: markerDir) }

        let invocation = try spawn(
            addonRoot: addonRoot,
            entrypoint: entrypoint,
            request: request,
            extraEnvironment: extraEnvironment,
            markerDir: markerDir
        )
        return try invocation.waitForResponseSync(timeout: timeout)
    }
}

public enum AddonRunnerError: Error, Equatable {
    case unsupportedEntrypointKind(String)
    case timeout
    case invalidResponse
    case helperMissing(String)
    case jobHandshakeTimeout
    case jobUnresponsive
}
