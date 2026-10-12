@testable import JugnuCore
import XCTest

final class FinderQuickActionsTests: XCTestCase {
    func test_menuStaysOffUntilConfigAndEnable() {
        let manifest = sampleManifest()
        XCTAssertTrue(FinderMenu.actions(manifest: manifest, enabled: true, config: [:]).isEmpty)
        XCTAssertTrue(
            FinderMenu.actions(
                manifest: manifest,
                enabled: false,
                config: [FinderMenu.configKey: .bool(true)]
            ).isEmpty
        )
        let actions = FinderMenu.actions(
            manifest: manifest,
            enabled: true,
            config: [FinderMenu.configKey: .bool(true)]
        )
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].menuTitle, "Remove PDF Password")
        XCTAssertEqual(actions[0].fileTypes, ["com.adobe.pdf"])
    }

    func test_syncWritesAndRemovesOnlyJugnuWorkflows() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-services-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let foreign = root.appendingPathComponent("Other.workflow/Contents")
        try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: true)
        let foreignInfo: [String: Any] = ["CFBundleIdentifier": "com.example.other"]
        let data = try PropertyListSerialization.data(fromPropertyList: foreignInfo, format: .xml, options: 0)
        try data.write(to: foreign.appendingPathComponent("Info.plist"))

        let action = FinderQuickAction(
            addonID: "jugnu.pdf-tools",
            commandID: "pdf-unlock",
            menuTitle: "Remove PDF Password",
            fileTypes: ["com.adobe.pdf"]
        )
        try FinderQuickActions.sync(desired: [action], servicesDirectory: root, refreshServices: false)
        let workflow = root.appendingPathComponent("jugnu.pdf-tools pdf-unlock.workflow")
        let info = try Data(contentsOf: workflow.appendingPathComponent("Contents/Info.plist"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "app.jugnu.finder.jugnu.pdf-tools.pdf-unlock")
        let services = try XCTUnwrap(plist["NSServices"] as? [[String: Any]])
        XCTAssertEqual(services[0]["NSSendFileTypes"] as? [String], ["com.adobe.pdf"])
        let documentData = try Data(contentsOf: workflow.appendingPathComponent("Contents/document.wflow"))
        let document = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: documentData, format: nil) as? [String: Any]
        )
        let meta = try XCTUnwrap(document["workflowMetaData"] as? [String: Any])
        XCTAssertEqual(
            meta["serviceInputTypeIdentifier"] as? String,
            "com.apple.Automator.fileSystemObject"
        )
        XCTAssertEqual(meta["serviceProcessesInput"] as? Int, 0)
        let xml = try XCTUnwrap(String(data: documentData, encoding: .utf8))
        XCTAssertTrue(xml.contains("jugnu://finder?addon=jugnu.pdf-tools&amp;command=pdf-unlock"))
        XCTAssertTrue(xml.contains("printf '%s\\0'"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.appendingPathComponent("Info.plist").path))

        try FinderQuickActions.sync(desired: [], servicesDirectory: root, refreshServices: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: workflow.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.appendingPathComponent("Info.plist").path))
    }

    func test_parseRejectsUnsafeQueueIDs() {
        let good =
            URL(
                string: "jugnu://finder?addon=jugnu.pdf-tools&command=pdf-unlock&id=2F6C5B3A-1C0D-4E5F-8A7B-9C0D1E2F3A4B"
            )
        XCTAssertEqual(try FinderQuickActions.parse(XCTUnwrap(good))?.commandID, "pdf-unlock")
        let slash = URL(string: "jugnu://finder?addon=jugnu.pdf-tools&command=pdf-unlock&id=../secret")
        XCTAssertNil(try FinderQuickActions.parse(XCTUnwrap(slash)))
    }

    func test_readQueueSplitsOnNUL() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("queue-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("one.pdf\0two.pdf\0".utf8).write(to: file)
        XCTAssertEqual(FinderQuickActions.readQueue(at: file), ["one.pdf", "two.pdf"])
    }

    func test_pdfToolsManifestDeclaresFinderOptIn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("addons/jugnu.pdf-tools")
        let manifest = try ManifestLoader.load(from: root)
        XCTAssertEqual(manifest.primary, "pdf-unlock")
        XCTAssertEqual(manifest.commands.first?.finder?.menuTitle(commandTitle: ""), "Remove PDF Password")
        XCTAssertEqual(
            manifest.config.first { $0.key == FinderMenu.configKey }?.default,
            .bool(false)
        )
    }

    private func sampleManifest() -> AddonManifest {
        AddonManifest(
            id: "jugnu.pdf-tools",
            name: "PDF Tools",
            version: "1.0.0",
            api: 1,
            commands: [
                CommandDescriptor(
                    id: "pdf-unlock",
                    title: "Remove PDF password",
                    subtitle: "Save an unlocked copy beside the PDF",
                    finder: FinderAction(title: "Remove PDF Password", types: ["com.adobe.pdf"])
                )
            ],
            entrypoint: Entrypoint(kind: "exec", path: "bin/run"),
            config: [
                AddonConfigField(key: FinderMenu.configKey, type: .bool, default: .bool(false))
            ],
            primary: "pdf-unlock"
        )
    }
}
