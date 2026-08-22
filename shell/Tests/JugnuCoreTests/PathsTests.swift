import XCTest
@testable import JugnuCore

final class PathsTests: XCTestCase {
    func testDefaultLayoutUnderHome() {
        let home = URL(fileURLWithPath: "/tmp/jugnu-home-test")
        let paths = JugnuPaths(home: home)
        XCTAssertEqual(paths.configFile.path, "/tmp/jugnu-home-test/.config/jugnu/jugnu.yaml")
        XCTAssertEqual(paths.addonsDir.path, "/tmp/jugnu-home-test/.local/share/jugnu/addons")
    }
}
