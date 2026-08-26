@testable import JugnuCore
import XCTest

final class PathsTests: XCTestCase {
    func testDefaultLayoutUnderHome() {
        let home = URL(fileURLWithPath: "/tmp/jugnu-home-test")
        let paths = JugnuPaths(home: home)
        XCTAssertEqual(paths.configFile.path, "/tmp/jugnu-home-test/.config/jugnu/jugnu.yaml")
        XCTAssertEqual(paths.addonsDir.path, "/tmp/jugnu-home-test/.local/share/jugnu/addons")
        XCTAssertEqual(paths.helpersDir.path, "/tmp/jugnu-home-test/.local/share/jugnu/helpers")
        XCTAssertEqual(
            paths.helperRoot(id: "play-runtime", version: "1.0.0").path,
            "/tmp/jugnu-home-test/.local/share/jugnu/helpers/play-runtime/1.0.0"
        )
    }
}
