import CryptoKit
import XCTest
@testable import JugnuCore

final class HelperInstallTests: XCTestCase {
    func testHelpersCatalogURLReplacesAddonsJson() {
        XCTAssertEqual(
            ShellConfig.helpersCatalogURL(from: "https://example.com/registry/addons.json"),
            "https://example.com/registry/helpers.json"
        )
    }

    func testInstallHelperFromLocalZip() throws {
        let ctx = try makeHome()
        defer { ctx.tearDown() }

        let zip = try makeHelperZip(in: ctx.home, id: "play-runtime", version: "1.0.0")
        let digest = try sha256(of: zip)
        let installer = AddonInstaller(paths: ctx.paths)
        try installer.installHelperFromLocalZip(
            url: zip,
            expectedSHA256: digest,
            id: "play-runtime",
            version: "1.0.0"
        )

        let root = ctx.paths.helperRoot(id: "play-runtime", version: "1.0.0")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("helper.yaml").path))
    }

    func testEnsureHelpersSkipsDownloadWhenAlreadyOnDisk() async throws {
        let ctx = try makeHome()
        defer { ctx.tearDown() }

        let zip = try makeHelperZip(in: ctx.home, id: "play-runtime", version: "1.0.0")
        let installer = AddonInstaller(paths: ctx.paths)
        try installer.installHelperFromLocalZip(url: zip, expectedSHA256: nil, id: "play-runtime", version: "1.0.0")

        try writeRegistryURL(home: ctx.home, addonsJSON: "not-a-url")
        let manifest = AddonManifest(
            id: "dice-roll",
            name: "Dice",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            helpers: [HelperRef(id: "play-runtime", version: "1.0.0")]
        )
        try await installer.ensureHelpers(for: manifest)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: ctx.paths.helperRoot(id: "play-runtime", version: "1.0.0")
                    .appendingPathComponent("helper.yaml").path
            )
        )
    }

    func testEnsureHelpersDownloadsMissingHelperFromFileCatalog() async throws {
        let ctx = try makeHome()
        defer { ctx.tearDown() }

        let helperZip = try makeHelperZip(in: ctx.home, id: "play-runtime", version: "1.0.0")
        let digest = try sha256(of: helperZip)
        let catalogDir = ctx.home.appendingPathComponent("catalog")
        try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
        let helpersJSON = """
        [{"id":"play-runtime","version":"1.0.0","url":"\(helperZip.absoluteString)","sha256":"\(digest)"}]
        """
        try helpersJSON.write(
            to: catalogDir.appendingPathComponent("helpers.json"),
            atomically: true,
            encoding: .utf8
        )
        try "[]".write(to: catalogDir.appendingPathComponent("addons.json"), atomically: true, encoding: .utf8)
        try writeRegistryURL(home: ctx.home, addonsJSON: catalogDir.appendingPathComponent("addons.json").absoluteString)

        let installer = AddonInstaller(paths: ctx.paths)
        let manifest = AddonManifest(
            id: "dice-roll",
            name: "Dice",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            helpers: [HelperRef(id: "play-runtime", version: "1.0.0")]
        )
        try await installer.ensureHelpers(for: manifest)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: ctx.paths.helperRoot(id: "play-runtime", version: "1.0.0")
                    .appendingPathComponent("helper.yaml").path
            )
        )
    }

    func testEnsureHelpersFailsOfflineWhenMissing() async throws {
        let ctx = try makeHome()
        defer { ctx.tearDown() }

        try writeRegistryURL(home: ctx.home, addonsJSON: "file:///no-such-jugnu-catalog/addons.json")
        let installer = AddonInstaller(paths: ctx.paths)
        let manifest = AddonManifest(
            id: "dice-roll",
            name: "Dice",
            version: "1.0.0",
            api: 1,
            commands: [],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            helpers: [HelperRef(id: "play-runtime", version: "1.0.0")]
        )
        do {
            try await installer.ensureHelpers(for: manifest)
            XCTFail("expected failure")
        } catch let error as AddonInstallerError {
            guard case .helperUnreachable = error else {
                return XCTFail("expected helperUnreachable, got \(error)")
            }
        }
        XCTAssertEqual(
            UserFacingError.message(for: AddonInstallerError.helperUnreachable),
            "Couldn’t download the helper. Check your connection and try again."
        )
    }

    func testUninstallLastConsumerRemovesHelper() throws {
        let ctx = try makeHome()
        defer { ctx.tearDown() }

        let zip = try makeHelperZip(in: ctx.home, id: "play-runtime", version: "1.0.0")
        let installer = AddonInstaller(paths: ctx.paths)
        try installer.installHelperFromLocalZip(url: zip, expectedSHA256: nil, id: "play-runtime", version: "1.0.0")
        try installAddonDeclaringHelper(id: "dice-roll", paths: ctx.paths)

        let life = AddonLifecycle(paths: ctx.paths)
        try life.uninstall(id: "dice-roll")

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: ctx.paths.helperRoot(id: "play-runtime", version: "1.0.0").path
            )
        )
    }

    func testUninstallKeepsHelperWhenAnotherAddonStillListsIt() throws {
        let ctx = try makeHome()
        defer { ctx.tearDown() }

        let zip = try makeHelperZip(in: ctx.home, id: "play-runtime", version: "1.0.0")
        try AddonInstaller(paths: ctx.paths).installHelperFromLocalZip(
            url: zip,
            expectedSHA256: nil,
            id: "play-runtime",
            version: "1.0.0"
        )
        try installAddonDeclaringHelper(id: "dice-roll", paths: ctx.paths)
        try installAddonDeclaringHelper(id: "coin-flip", paths: ctx.paths)

        try AddonLifecycle(paths: ctx.paths).uninstall(id: "dice-roll")

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: ctx.paths.helperRoot(id: "play-runtime", version: "1.0.0")
                    .appendingPathComponent("helper.yaml").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ctx.paths.addonsDir.appendingPathComponent("dice-roll").path)
        )
    }

    private struct Home {
        let home: URL
        let paths: JugnuPaths
        func tearDown() {
            try? FileManager.default.removeItem(at: home)
        }
    }

    private func makeHome() throws -> Home {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return Home(home: home, paths: JugnuPaths(home: home))
    }

    private func writeRegistryURL(home: URL, addonsJSON: String) throws {
        let paths = JugnuPaths(home: home)
        try FileManager.default.createDirectory(
            at: paths.configFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let yaml = """
        version: 1
        shell:
          registry_url: "\(addonsJSON)"
        addons: {}
        """
        try yaml.write(to: paths.configFile, atomically: true, encoding: .utf8)
    }

    private func makeHelperZip(in home: URL, id: String, version: String) throws -> URL {
        let staging = home.appendingPathComponent("staging/\(id)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let yaml = """
        id: \(id)
        version: \(version)
        """
        try yaml.write(to: staging.appendingPathComponent("helper.yaml"), atomically: true, encoding: .utf8)
        let zipURL = home.appendingPathComponent("\(id)-\(version).zip")
        try zipDirectory(staging, to: zipURL)
        return zipURL
    }

    private func installAddonDeclaringHelper(id: String, paths: JugnuPaths) throws {
        let root = paths.addonsDir.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let yaml = """
        id: \(id)
        name: \(id)
        version: 1.0.0
        api: 1
        helpers:
          - id: play-runtime
            version: 1.0.0
        commands: []
        entrypoint:
          kind: exec
          path: bin/run
        """
        try yaml.write(to: root.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        var config = try ConfigStore(paths: paths).loadOrCreateDefaults()
        config.addons[id] = AddonConfig(enabled: true)
        try ConfigStore(paths: paths).save(config)
    }

    private func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func zipDirectory(_ dir: URL, to zipURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = dir.deletingLastPathComponent()
        process.arguments = ["-qr", zipURL.path, dir.lastPathComponent]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
