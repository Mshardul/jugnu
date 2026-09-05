import Foundation

public enum ShellVersion {
    /// Marketing version of the running app (`CFBundleShortVersionString`), or `0.1.0` in tests/CLI.
    public static var current: String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !v.isEmpty {
            return v
        }
        return "0.1.0"
    }
}

public enum PackageGates {
    public static func checkMinShellVersion(required: String?, running: String) throws {
        guard let required, !required.isEmpty else { return }
        guard isValidSemVer(required) else {
            throw AddonInstallerError.invalidMinShellVersion(required)
        }
        if compareSemVer(running, required) == .orderedAscending {
            throw AddonInstallerError.shellTooOld(required: required, running: running)
        }
    }

    /// Returns true when the installed addon may be indexed/invoked on this shell.
    public static func isRunnable(minShellVersion: String?, running: String) -> Bool {
        do {
            try checkMinShellVersion(required: minShellVersion, running: running)
            return true
        } catch {
            return false
        }
    }

    public static func checkEntrypoint(kind: String, fileURL: URL) throws {
        guard kind == "exec" else { return }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let prefix = handle.readData(ofLength: 2)
        if prefix == Data([0x23, 0x21]) { // #!
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-archs", fileURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AddonInstallerError.nonUniversalBinary
        }
        guard process.terminationStatus == 0 else {
            throw AddonInstallerError.nonUniversalBinary
        }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let archs = Set(out.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        guard archs.contains("arm64"), archs.contains("x86_64") else {
            throw AddonInstallerError.nonUniversalBinary
        }
    }

    public static func validateAddonId(_ id: String) throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ManifestLoaderError.emptyId }
        if trimmed.hasPrefix(".") || trimmed == ".staging" || trimmed == ".trash" {
            throw ManifestLoaderError.reservedId(trimmed)
        }
        // Catalog shape: <publisher>.<job>. Bare job ids are still accepted while trees migrate.
        let namespaced = #"^[a-z0-9]+\.[a-z0-9][a-z0-9-]*$"#
        let bare = #"^[a-z0-9][a-z0-9-]*$"#
        let ok =
            trimmed.range(of: namespaced, options: .regularExpression) != nil
            || trimmed.range(of: bare, options: .regularExpression) != nil
        guard ok else {
            throw ManifestLoaderError.invalidId(trimmed)
        }
    }

    /// Strict catalog rule after migration sources are namespaced.
    public static func validateNamespacedAddonId(_ id: String) throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ManifestLoaderError.emptyId }
        let namespaced = #"^[a-z0-9]+\.[a-z0-9][a-z0-9-]*$"#
        guard trimmed.range(of: namespaced, options: .regularExpression) != nil else {
            throw ManifestLoaderError.invalidId(trimmed)
        }
    }

    public static func compareSemVer(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = parseSemVer(lhs)
        let b = parseSemVer(rhs)
        if a.0 != b.0 { return a.0 < b.0 ? .orderedAscending : .orderedDescending }
        if a.1 != b.1 { return a.1 < b.1 ? .orderedAscending : .orderedDescending }
        if a.2 != b.2 { return a.2 < b.2 ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }

    public static func isValidSemVer(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil
    }

    private static func parseSemVer(_ value: String) -> (Int, Int, Int) {
        let parts = value.split(separator: ".").map { Int($0) ?? 0 }
        return (parts.count > 0 ? parts[0] : 0, parts.count > 1 ? parts[1] : 0, parts.count > 2 ? parts[2] : 0)
    }
}
