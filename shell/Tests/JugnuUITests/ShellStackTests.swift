@testable import JugnuUI
import XCTest

final class ShellStackTests: XCTestCase {
    func test_initialStack_isLauncherOnly() {
        let stack = ShellStack()
        XCTAssertEqual(stack.entries.count, 1)
        XCTAssertEqual(stack.top.preset, .launcher)
        XCTAssertTrue(stack.isAtRoot)
    }

    func test_push_addsChild() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: nil,
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        XCTAssertEqual(stack.entries.count, 2)
        XCTAssertEqual(stack.top.preset, .catalog)
        XCTAssertFalse(stack.isAtRoot)
    }

    func test_pushSamePreset_isIdempotent_updatesTopInPlace() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: nil,
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        stack.push(ShellStackEntry(.catalog(
            category: "Clipboard",
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        XCTAssertEqual(stack.entries.count, 2, "must not push a second catalog entry")
        if case let .catalog(category, _, _, _, _, _) = stack.top.state {
            XCTAssertEqual(category, "Clipboard", "idempotent push still refocuses/updates state in place")
        } else {
            XCTFail("expected catalog state")
        }
    }

    func test_replace_swapsSibling_keepsParent() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: nil,
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        stack.replace(ShellStackEntry(.settings(scroll: 0, focusedControlID: nil)))
        XCTAssertEqual(stack.entries.count, 2, "replace does not grow the stack")
        XCTAssertEqual(stack.top.preset, .settings)
        XCTAssertEqual(stack.entries[0].preset, .launcher, "launcher parent stays under the replaced sibling")
    }

    func test_pop_restoresParent() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: nil,
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        stack.push(ShellStackEntry(.detail(addonID: "mic-mute")))
        stack.pop()
        XCTAssertEqual(stack.top.preset, .catalog)
        XCTAssertEqual(stack.entries.count, 2)
    }

    func test_pop_atRoot_isNoOp() {
        var stack = ShellStack()
        stack.pop()
        XCTAssertEqual(stack.entries.count, 1)
        XCTAssertEqual(stack.top.preset, .launcher)
    }

    func test_home_resetsToFreshLauncherOnly() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: "X",
            subcategory: nil,
            tags: [],
            query: "abc",
            scroll: 5,
            selectedCardID: "id"
        )))
        stack.home(initial: .launcher(query: "", selection: nil, scroll: 0))
        XCTAssertEqual(stack.entries.count, 1)
        XCTAssertEqual(stack.top.preset, .launcher)
        if case let .launcher(query, _, _) = stack.top.state {
            XCTAssertEqual(query, "", "home must not restore the previous launcher query")
        } else {
            XCTFail("expected launcher state")
        }
    }

    func test_clear_emptiesStack() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: nil,
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        stack.clear()
        XCTAssertEqual(stack.entries.count, 0)
    }

    func test_deepPush_listDrillDown() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.list(query: "", highlightedID: nil, scroll: 0)))
        stack.push(ShellStackEntry(.confirm))
        XCTAssertEqual(stack.entries.map(\.preset), [.launcher, .list, .confirm])
        stack.pop()
        XCTAssertEqual(stack.top.preset, .list, "cancel on confirm pops back to the same list, not launcher")
    }

    func test_invokeOutcome_notVisible_showsHome() {
        let stack = ShellStack()
        XCTAssertEqual(decideInvokeOutcome(stack: stack, isVisible: false), .showHome)
    }

    func test_invokeOutcome_visibleOnLauncher_closes() {
        let stack = ShellStack()
        XCTAssertEqual(decideInvokeOutcome(stack: stack, isVisible: true), .close)
    }

    func test_invokeOutcome_visibleOnCatalog_showsHome() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(
            category: nil,
            subcategory: nil,
            tags: [],
            query: "",
            scroll: 0,
            selectedCardID: nil
        )))
        XCTAssertEqual(decideInvokeOutcome(stack: stack, isVisible: true), .showHome)
    }
}
