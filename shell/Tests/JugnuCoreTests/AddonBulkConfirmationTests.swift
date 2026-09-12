@testable import JugnuCore
import XCTest

final class AddonBulkConfirmationTests: XCTestCase {
    func testConfirmAddonBulkUICopy() {
        let ui = confirmAddonBulkUI(count: 3)
        XCTAssertEqual(ui.pattern, .confirm)
        XCTAssertEqual(ui.title, "Update addons?")
        XCTAssertEqual(ui.message, "3 addons have updates. Update all?")
        XCTAssertEqual(ui.confirmLabel, "Update")
        XCTAssertEqual(ui.cancelLabel, "Later")
    }

    func testConfirmAddonBulkUIIncludesGrowths() {
        let ui = confirmAddonBulkUI(
            count: 2,
            growthExpand: [
                (permission: .accessibility, addonNames: ["Window Layouts"]),
                (permission: .clipboard, addonNames: ["Clip Tools"])
            ]
        )
        XCTAssertTrue(ui.message?.contains("2 addons have updates. Update all?") == true)
        XCTAssertTrue(ui.message?.contains("Some updates newly need:") == true)
        XCTAssertTrue(ui.message?.contains("Accessibility\n  • Window Layouts") == true)
        XCTAssertTrue(ui.message?.contains("Clipboard\n  • Clip Tools") == true)
    }

    func testGrowthExpandUnionsNewPermissionsOnly() {
        let outdated = [
            RegistryEntry(
                id: "layouts", name: "Window Layouts", version: "2.0.0", api: 1,
                url: "https://x/l.zip", sha256: "a", summary: "", category: "System",
                permissions: [.accessibility, .clipboard]
            ),
            RegistryEntry(
                id: "clip", name: "Clip Tools", version: "2.0.0", api: 1,
                url: "https://x/c.zip", sha256: "b", summary: "", category: "Tools",
                permissions: [.clipboard]
            )
        ]
        let expand = AddonBulkPermissions.growthExpand(outdated: outdated) { id in
            id == "layouts" ? [.clipboard] : []
        }
        XCTAssertEqual(expand.map(\.permission), [.accessibility, .clipboard])
        XCTAssertEqual(expand[0].addonNames, ["Window Layouts"])
        XCTAssertEqual(expand[1].addonNames, ["Clip Tools"])
    }
}
