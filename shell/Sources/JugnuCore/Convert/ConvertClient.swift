import Foundation

public enum ConvertClientError: Error, Equatable, Sendable {
    case failed(String)
}

public struct ConvertClient: Sendable {
    public var runner: AddonRunner
    public var paths: JugnuPaths?
    public var timeout: TimeInterval

    public init(runner: AddonRunner = AddonRunner(), paths: JugnuPaths? = nil, timeout: TimeInterval = 5) {
        self.runner = runner
        self.paths = paths
        self.timeout = timeout
    }

    public func convertText(
        _ text: String,
        route: ConvertRoute,
        manifest: AddonManifest,
        addonRoot: URL
    ) async throws -> String {
        let request = RunRequest(op: "convert", command: route.command, from: route.from, to: route.to, text: text)
        let response = try await send(request, route: route, manifest: manifest, addonRoot: addonRoot)
        guard response.ok, let out = response.text else {
            throw ConvertClientError.failed(response.error ?? "Conversion failed.")
        }
        return out
    }

    public func convertFile(
        _ input: URL,
        outputExtension: String,
        outputDirectory: URL? = nil,
        route: ConvertRoute,
        manifest: AddonManifest,
        addonRoot: URL
    ) async throws -> URL {
        let output = if let outputDirectory {
            try ConvertOutput.reserve(
                directory: outputDirectory,
                baseName: input.deletingPathExtension().lastPathComponent,
                ext: outputExtension
            )
        } else {
            try ConvertOutput.besideOriginal(input, ext: outputExtension)
        }
        do {
            let request = RunRequest(
                op: "convert",
                command: route.command,
                from: route.from,
                to: route.to,
                path: input.path,
                out: output.path
            )
            let response = try await send(request, route: route, manifest: manifest, addonRoot: addonRoot)
            guard response.ok else {
                throw ConvertClientError.failed(response.error ?? "Conversion failed.")
            }
            return output
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    private func send(
        _ request: RunRequest,
        route: ConvertRoute,
        manifest: AddonManifest,
        addonRoot: URL
    ) async throws -> RunResponse {
        var extra = try AddonRunner.helperEnvironment(manifest: manifest, paths: paths)
        if let paths {
            extra["JUGNU_STATE_DIR"] = paths.addonStateRoot(id: manifest.id).path
            extra["JUGNU_CONFIG_DIR"] = paths.addonConfigDir(id: manifest.id).path
        }
        let markerDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-convert-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: markerDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: markerDir) }

        let invocation = try runner.spawn(
            addonRoot: addonRoot,
            entrypoint: manifest.entrypoint,
            request: request,
            extraEnvironment: extra,
            origin: "\(manifest.id):\(route.command):convert",
            markerDir: markerDir
        )
        return try await invocation.waitForResponse(timeout: timeout)
    }
}
