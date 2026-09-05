import XCTest
@testable import JugnuCore

final class InstallTransactionTests: XCTestCase {
    private var root: URL!
    private var paths: JugnuPaths!
    private var store: ConfigStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("jugnu-tx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        paths = JugnuPaths(home: root)
        try FileManager.default.createDirectory(at: paths.addonsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.helpersDir, withIntermediateDirectories: true)
        store = ConfigStore(paths: paths)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRollbackRemovesCreatedAddonAndHelper() throws {
        var tx = InstallTransaction(paths: paths, store: store)

        let addonStaging = paths.addonsStagingDir.appendingPathComponent("dep-stage")
        try FileManager.default.createDirectory(at: addonStaging, withIntermediateDirectories: true)
        try "id: dep\n".write(to: addonStaging.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)

        let helperStaging = paths.helpersStagingDir.appendingPathComponent("h-stage")
        try FileManager.default.createDirectory(at: helperStaging, withIntermediateDirectories: true)
        try "id: clock\nversion: 1.0.0\n".write(
            to: helperStaging.appendingPathComponent("helper.yaml"), atomically: true, encoding: .utf8
        )

        try tx.commitHelper(staging: helperStaging, id: "clock", version: "1.0.0")
        try tx.commitAddons(
            staged: ["dep": addonStaging],
            order: ["dep"],
            primaryId: "root",
            enablePrimary: true
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.addonsDir.appendingPathComponent("dep").path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: paths.helperRoot(id: "clock", version: "1.0.0").path)
        )
        XCTAssertEqual(try store.loadOrCreateDefaults().addons["dep"]?.enabled, false)

        tx.rollback()

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.addonsDir.appendingPathComponent("dep").path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: paths.helperRoot(id: "clock", version: "1.0.0").path)
        )
        XCTAssertNil(try store.loadOrCreateDefaults().addons["dep"])
    }

    func testPrimaryEnableOnly() throws {
        var tx = InstallTransaction(paths: paths, store: store)
        let depStaging = try makeAddonStaging(id: "dep")
        let rootStaging = try makeAddonStaging(id: "root")
        try tx.commitAddons(
            staged: ["dep": depStaging, "root": rootStaging],
            order: ["dep", "root"],
            primaryId: "root",
            enablePrimary: true
        )
        let config = try store.loadOrCreateDefaults()
        XCTAssertEqual(config.addons["dep"]?.enabled, false)
        XCTAssertEqual(config.addons["root"]?.enabled, true)
    }

    private func makeAddonStaging(id: String) throws -> URL {
        let staging = paths.addonsStagingDir.appendingPathComponent("\(id)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try "id: \(id)\n".write(to: staging.appendingPathComponent("addon.yaml"), atomically: true, encoding: .utf8)
        return staging
    }
}
