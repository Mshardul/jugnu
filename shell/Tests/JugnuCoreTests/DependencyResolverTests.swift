import XCTest
@testable import JugnuCore

final class DependencyResolverTests: XCTestCase {
    func testTopoOrderDepsBeforePrimary() throws {
        let leaf = DeclaredAddon(id: "leaf", name: "Leaf", version: "1.0.0")
        let mid = DeclaredAddon(
            id: "mid", name: "Mid", version: "1.0.0",
            dependencies: [AddonDependency(id: "leaf", version: "1.0.0")]
        )
        let root = DeclaredAddon(
            id: "root", name: "Root", version: "2.0.0",
            dependencies: [AddonDependency(id: "mid", version: "1.0.0")]
        )
        let catalog = ["leaf": leaf, "mid": mid, "root": root]
        let plan = try DependencyResolver.plan(root: root, catalog: catalog, installed: [:])
        XCTAssertEqual(plan.installOrder, ["leaf", "mid", "root"])
        XCTAssertEqual(plan.dependencies.map(\.id).sorted(), ["leaf", "mid"])
        XCTAssertTrue(plan.dependencies.allSatisfy { $0.status == .willInstall })
    }

    func testAlreadyInstalledSkippedFromInstallOrder() throws {
        let dep = DeclaredAddon(id: "dep", name: "Dep", version: "1.0.0")
        let root = DeclaredAddon(
            id: "root", name: "Root", version: "1.0.0",
            dependencies: [AddonDependency(id: "dep", version: "1.0.0")]
        )
        let plan = try DependencyResolver.plan(
            root: root,
            catalog: ["dep": dep, "root": root],
            installed: ["dep": "1.0.0"]
        )
        XCTAssertEqual(plan.installOrder, ["root"])
        XCTAssertEqual(plan.dependencies.first?.status, .alreadyInstalled)
    }

    func testExactVersionMismatchRefuses() {
        let dep = DeclaredAddon(id: "dep", name: "Dep", version: "1.0.0")
        let root = DeclaredAddon(
            id: "root", name: "Root", version: "1.0.0",
            dependencies: [AddonDependency(id: "dep", version: "1.0.0")]
        )
        XCTAssertThrowsError(
            try DependencyResolver.plan(
                root: root,
                catalog: ["dep": dep, "root": root],
                installed: ["dep": "1.1.0"]
            )
        ) {
            guard case DependencyResolverError.versionMismatch(let id, let req, let have) = $0 else {
                return XCTFail("\(String(describing: $0))")
            }
            XCTAssertEqual(id, "dep")
            XCTAssertEqual(req, "1.0.0")
            XCTAssertEqual(have, "1.1.0")
        }
    }

    func testUnknownDependencyFails() {
        let root = DeclaredAddon(
            id: "root", name: "Root", version: "1.0.0",
            dependencies: [AddonDependency(id: "missing", version: "1.0.0")]
        )
        XCTAssertThrowsError(
            try DependencyResolver.plan(root: root, catalog: ["root": root], installed: [:])
        ) {
            guard case DependencyResolverError.unknown(let id) = $0 else {
                return XCTFail("\(String(describing: $0))")
            }
            XCTAssertEqual(id, "missing")
        }
    }

    func testCycleFails() {
        let a = DeclaredAddon(
            id: "a", name: "A", version: "1.0.0",
            dependencies: [AddonDependency(id: "b", version: "1.0.0")]
        )
        let b = DeclaredAddon(
            id: "b", name: "B", version: "1.0.0",
            dependencies: [AddonDependency(id: "a", version: "1.0.0")]
        )
        XCTAssertThrowsError(
            try DependencyResolver.plan(root: a, catalog: ["a": a, "b": b], installed: [:])
        ) {
            guard case DependencyResolverError.cycle = $0 else {
                return XCTFail("\(String(describing: $0))")
            }
        }
    }

    func testCollisionRefuseNonJugnu() {
        XCTAssertThrowsError(
            try DependencyResolver.checkCollision(
                installing: "other.clip-tools",
                installedIds: ["jugnu.clip-tools"]
            )
        ) {
            guard case DependencyResolverError.collision = $0 else {
                return XCTFail("\(String(describing: $0))")
            }
        }
    }

    func testJugnuWinsCollision() throws {
        try DependencyResolver.checkCollision(
            installing: "jugnu.clip-tools",
            installedIds: ["other.clip-tools"]
        )
    }
}
