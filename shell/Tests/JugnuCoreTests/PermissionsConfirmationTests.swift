@testable import JugnuCore
import XCTest

final class PermissionsConfirmationTests: XCTestCase {
    func testInstallUI() {
        let ui = confirmPermissionsInstallUI(
            addonName: "Window Layouts",
            permissions: [.accessibility, .clipboard]
        )
        XCTAssertEqual(ui.pattern, .confirm)
        XCTAssertEqual(ui.title, "Install Window Layouts?")
        XCTAssertEqual(ui.confirmLabel, "Install")
        XCTAssertEqual(ui.cancelLabel, "Cancel")
        XCTAssertTrue(ui.message?.contains("This addon will need:") == true)
        XCTAssertTrue(ui.message?.contains("• Accessibility") == true)
        XCTAssertTrue(ui.message?.contains("• Clipboard") == true)
    }

    func testMultiUINestsAddonNames() {
        let ui = confirmPermissionsMultiUI(expand: [
            (permission: .accessibility, addonNames: ["Window Layouts"]),
            (permission: .clipboard, addonNames: ["Clip Tools", "History"]),
        ])
        XCTAssertEqual(ui.title, "Install these addons?")
        XCTAssertTrue(ui.message?.contains("They will need:") == true)
        XCTAssertTrue(ui.message?.contains("Accessibility\n  • Window Layouts") == true)
        XCTAssertTrue(ui.message?.contains("Clipboard\n  • Clip Tools\n  • History") == true)
    }

    func testGrewUI() {
        let ui = confirmPermissionsGrewUI(addonName: "Layouts", newPermissions: [.accessibility])
        XCTAssertEqual(ui.title, "Update Layouts?")
        XCTAssertEqual(ui.confirmLabel, "Update")
        XCTAssertTrue(ui.message?.contains("This version newly needs:") == true)
        XCTAssertTrue(ui.message?.contains("• Accessibility") == true)
    }

    func testCombinedDisclosure() {
        let plan = DependencyPlan(
            primaryId: "jugnu.root",
            primaryName: "Root",
            dependencies: [
                DependencyPlanItem(id: "jugnu.dep", name: "Dep", version: "1.0.0", status: .willInstall),
            ],
            installOrder: ["jugnu.dep", "jugnu.root"]
        )
        let body = "This addon will need:\n• Clipboard"
        let ui = confirmInstallDisclosureUI(
            permissionsTitle: "Install Root?",
            permissionsBody: body,
            dependencyPlan: plan
        )
        XCTAssertEqual(ui.title, "Install Root?")
        XCTAssertTrue(ui.message?.contains("This addon will need:") == true)
        XCTAssertTrue(ui.message?.contains("will be installed now") == true)
        XCTAssertTrue(ui.message?.contains("Installed is not the same as enabled") == true)
    }

    func testConfirmPreTCCExplainerUI() {
        let ui = confirmPreTCCExplainerUI(
            addonName: "Window Layouts",
            permission: .accessibility
        )
        XCTAssertEqual(ui.pattern, .confirm)
        XCTAssertEqual(ui.title, "Window Layouts")
        XCTAssertEqual(
            ui.message,
            "Window Layouts needs Accessibility to Control other apps’ windows."
        )
        XCTAssertEqual(ui.confirmLabel, "Open System Settings")
        XCTAssertEqual(ui.cancelLabel, "Not now")
    }
}
