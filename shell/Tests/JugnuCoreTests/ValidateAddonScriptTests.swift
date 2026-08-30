import XCTest

final class ValidateAddonScriptTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var script: URL {
        repoRoot.appendingPathComponent("scripts/validate-addon.sh")
    }

    private var casesDir: URL {
        repoRoot.appendingPathComponent("shell/Tests/validate-addon-cases")
    }

    private struct Run {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private func run(_ addonDir: URL) throws -> Run {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, addonDir.path]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Run(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }

    private func fixture(_ name: String) -> URL {
        casesDir.appendingPathComponent(name)
    }

    func test_validateAddon_validOneshot_passes() throws {
        let result = try run(fixture("valid-oneshot"))
        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("valid addon: valid-oneshot"))
    }

    func test_validateAddon_sessionLifecycle_rejected() throws {
        let result = try run(fixture("session-rejected"))
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.stderr.contains("session addons are not yet supported"), result.stderr)
    }

    func test_validateAddon_daemonNotAllowlisted_rejected() throws {
        let result = try run(fixture("daemon-not-allowlisted"))
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.stderr.contains("daemon lifecycle is first-party only"), result.stderr)
    }

    func test_validateAddon_daemonMissingBlock_rejected() throws {
        let result = try run(fixture("daemon-missing-block"))
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.stderr.contains("daemon command missing daemon block"), result.stderr)
    }

    func test_validateAddon_daemonAllowlistedWithBlock_passes() throws {
        let result = try run(fixture("daemon-valid"))
        XCTAssertEqual(result.status, 0, result.stderr)
    }

    func test_validateAddon_timeoutOverCeiling_rejected() throws {
        let result = try run(fixture("timeout-too-big"))
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.stderr.contains("timeout must be"), result.stderr)
    }

    func test_validateAddon_disownInEntrypoint_warnsButPasses() throws {
        let result = try run(fixture("disown-warning"))
        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stderr.contains("background work belongs in a daemon"), result.stderr)
    }

    func test_validateAddon_allShippedAddons_pass() throws {
        let addonsDir = repoRoot.appendingPathComponent("addons")
        let entries = try FileManager.default.contentsOfDirectory(at: addonsDir, includingPropertiesForKeys: nil)
        let addons = entries.filter {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("addon.yaml").path)
        }
        XCTAssertGreaterThanOrEqual(addons.count, 19)
        for addon in addons {
            let result = try run(addon)
            XCTAssertEqual(result.status, 0, "\(addon.lastPathComponent): \(result.stderr)")
        }
    }
}
