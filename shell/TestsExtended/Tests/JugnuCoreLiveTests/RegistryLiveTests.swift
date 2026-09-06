import JugnuCore
import XCTest

final class RegistryLiveTests: XCTestCase {
    func testRegistryInstallsMicMuteIntoTempHome() async throws {
        let url = try XCTUnwrap(URL(string: ShellConfig.defaultRegistryURL))
        let entries: [RegistryEntry]
        do {
            entries = try await RegistryClient().fetch(from: url)
        } catch {
            throw XCTSkip("Registry unreachable: \(error)")
        }
        let mic = try XCTUnwrap(entries.first { $0.id == "jugnu.mic-mute" })
        XCTAssertFalse(mic.sha256.isEmpty)
        XCTAssertFalse(mic.url.isEmpty)
        XCTAssertTrue(mic.url.contains("jugnu.mic-mute"))

        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let installer = AddonInstaller(paths: paths)
        try await installer.install(entry: mic, enable: true)
        let manifestURL = paths.addonsDir.appendingPathComponent("jugnu.mic-mute/addon.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
        let yaml = try String(contentsOf: manifestURL, encoding: .utf8)
        XCTAssertTrue(yaml.contains("id: jugnu.mic-mute"))
    }

    func testRegistryInstallsClipToolsAndPythonRuntimeHelper() async throws {
        let url = try XCTUnwrap(URL(string: ShellConfig.defaultRegistryURL))
        let entries: [RegistryEntry]
        do {
            entries = try await RegistryClient().fetch(from: url)
        } catch {
            throw XCTSkip("Registry unreachable: \(error)")
        }
        let clip = try XCTUnwrap(entries.first { $0.id == "jugnu.clip-tools" })
        XCTAssertTrue(clip.url.contains("jugnu.clip-tools"))

        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let installer = AddonInstaller(paths: paths)
        try await installer.install(entry: clip, enable: true)

        let manifestURL = paths.addonsDir.appendingPathComponent("jugnu.clip-tools/addon.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
        let yaml = try String(contentsOf: manifestURL, encoding: .utf8)
        XCTAssertTrue(yaml.contains("id: jugnu.clip-tools"))

        let helperYAML = paths.helperRoot(id: "python-runtime", version: "1.0.0")
            .appendingPathComponent("helper.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: helperYAML.path))
        let python = paths.helperRoot(id: "python-runtime", version: "1.0.0")
            .appendingPathComponent("bin/python3")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: python.path))
    }

    func testClipboardHistoryUninstallCleansTempAddonWithoutTouchingExistingAgent() async throws {
        if launchctlListsClipboardHistory() || clipboardHistoryPlistExists() {
            throw XCTSkip(
                "clipboard-history already present on this Mac; skipping uninstall live test"
            )
        }

        let url = try XCTUnwrap(URL(string: ShellConfig.defaultRegistryURL))
        let entries: [RegistryEntry]
        do {
            entries = try await RegistryClient().fetch(from: url)
        } catch {
            throw XCTSkip("Registry unreachable: \(error)")
        }
        let clip = try XCTUnwrap(entries.first { $0.id == "jugnu.clipboard-history" })
        XCTAssertTrue(clip.url.contains("jugnu.clipboard-history"))

        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = JugnuPaths(home: home)
        let installer = AddonInstaller(paths: paths)
        let lifecycle = AddonLifecycle(paths: paths)
        try await installer.install(entry: clip, enable: true)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: paths.addonsDir.appendingPathComponent("jugnu.clipboard-history/addon.yaml").path
            )
        )
        try lifecycle.uninstall(id: "jugnu.clipboard-history")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: paths.addonsDir.appendingPathComponent("jugnu.clipboard-history").path
            )
        )
        XCTAssertFalse(launchctlListsClipboardHistory())
    }

    private func clipboardHistoryPlistExists() -> Bool {
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.jugnu.clipboard-history.watch.plist")
        return FileManager.default.fileExists(atPath: plist.path)
    }

    private func launchctlListsClipboardHistory() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.contains("com.jugnu.clipboard-history.watch")
    }
}
