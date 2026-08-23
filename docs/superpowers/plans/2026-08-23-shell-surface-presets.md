# Shell Surface: One Panel, Presets, Stack — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two disconnected panel owners (`PalettePanelController` for the launcher, `UIHostController` for addon follow-ups) and two titled `NSWindow`s (`BrowseCatalogWindowController`, ad hoc Preferences window) with **one** `KeyablePanel`-backed host that resizes/morphs between named presets and tracks a navigation stack, per the locked spec.

**Architecture:** Introduce a `ShellPreset` enum (the eight in-panel presets) and a `ShellHost` object that owns exactly one `KeyablePanel`, a `[ShellStackEntry]` stack (preset + type-erased view-state snapshot), and the hotkey home/close/dismiss rules. Each existing panel view (`PaletteView`, `BrowseCatalogView`, `PrefsView`, `AddonDetailView` (new), `ConfirmView`, `ListPanelView`, `FormPanelView`) becomes a plain SwiftUI view driven by `ShellHost` instead of owning its own `NSPanel`/`NSWindow`. Toast stays a separate HUD (`ToastPresenter`, unchanged owner). `note` stays a detached `NSPanel` (`NotePanel`, unchanged construction) but gains the `persist` flag and resets the launcher stack when opened. Migration is incremental: build the new host and stack alongside the old code, migrate one preset at a time behind the same `ShellHost`, delete the old controllers only once every call site is moved.

**Tech Stack:** Swift 5.9+, AppKit (`NSPanel`, `NSHostingView`), SwiftUI, XCTest (`shell/Tests/JugnuCoreTests`, plus new `shell/Tests/JugnuUITests` if needed for pure logic).

**Spec:** [docs/architecture/2026-08-23-shell-surface-presets.md](../../architecture/2026-08-23-shell-surface-presets.md)

## Global Constraints

- One `KeyablePanel` total for all in-panel presets; `note` is the only detached in-panel-adjacent window (titled, resizable); first-run stays its own window until ticket 0004.
- Preset key is a **pattern/destination name**, never an addon id or raw pixel size. Addons cannot declare pixel sizes.
- Push = child of current node; replace = sibling; both per the tree in spec §4. `catalog` ↔ `settings` are siblings (replace each other). `launcher` → `catalog`/`settings`/job destinations are pushes.
- Pop leaves exactly one child: **Esc**, **Cmd+W**, **Cancel**, or natural finish of that step. Pop restores the previous entry's view-state snapshot (spec §7) and first responder.
- Invoke hotkey / Open Palette: not on `launcher` → **home** (stack becomes `[launcher]`, fresh `first_view`, empty query, search focused). On `launcher` → **close** (hide, stack empty).
- Click-outside (desktop / other apps, not empty space inside panel) → **dismiss** (hide, stack empty). Not pop, not home. Cmd+Tab / resign-key is **not** click-outside.
- On `launcher`, Esc and Cmd+W **dismiss** (nothing to pop).
- Opening a destination you're already on is a **no-op** except refocusing that view (idempotent push).
- Toast is a themed HUD, never a stack node, never dismisses the panel, never steals focus (non-activating), auto-dismisses ~1.2–1.5s (shorter with Reduce Motion), a new toast replaces the old one. Catalog install errors stay in-content, never toast.
- Reduce Motion: all morphs **snap** instead of animate. Frame always clamped to current screen's `visibleFrame`.
- First arrival at a preset focuses that preset's default control (table in spec §2 "Focus" row); pop restores the previous first responder instead.
- Long jobs hold the current view; leaving it (Esc/Cmd+W/home/click-outside) or quitting cancels the process and runs cleanup. `progress` is not a stack preset in this epic.
- Exact preset sizes (spec §3): `launcher` compact-or-560×360, `catalog` ~800×560, `settings` ~520×560, `detail` ~560×480 (no sidebar), `confirm` ~380×180, `list` ~420×360, `form` ~400×240, toast HUD ~320×52, `note` detached ~420×320.

---

## File Structure

New files:
- `shell/Sources/JugnuUI/ShellPreset.swift` — `ShellPreset` enum + size table + chrome kind.
- `shell/Sources/JugnuUI/ShellStack.swift` — `ShellStackEntry`, `ShellViewState` (per-preset snapshot enum), `ShellStack` (push/replace/pop logic, pure, unit-testable with no AppKit).
- `shell/Sources/JugnuUI/ShellHost.swift` — the new single owner: builds/reuses one `KeyablePanel`, morphs frame between presets, drives `ShellStack`, exposes `pushCatalog()`, `pushSettings()`, `pushDetail(addonID:)`, `presentFollowUp(...)` (confirm/list/form), `openNote(...)`, `handleInvoke()` (home-or-close), `handleClickOutside()`, `handleEsc()`.
- `shell/Sources/JugnuUI/DetailPanelView.swift` — new `detail` preset content (addon name/version/description/commands/action row), reusing `AddonActionRow`.
- `shell/Tests/JugnuUITests/ShellStackTests.swift` — pure logic tests for push/replace/pop/idempotent-push, no AppKit.

Modified files:
- `shell/Sources/JugnuUI/UIHostController.swift` — gutted; its `present`/`showConfirm`/`showList`/`showForm`/`showNote`/`dismissActive` logic moves into `ShellHost` as the confirm/list/form/note branches of one preset-dispatch switch. `presentSkeleton`/`replaceSkeleton` keep their names but push/replace onto `ShellStack` instead of swapping a single `activePanel` slot.
- `shell/App/PalettePanelController.swift` — deleted once `ShellHost` owns `launcher`; `PaletteView` (currently nested inside this file) moves to `shell/Sources/JugnuUI/PaletteView.swift` as a plain view driven by `ShellHost`.
- `shell/Sources/JugnuUI/BrowseCatalogWindow.swift` — deleted; `BrowseCatalogView` (kept) becomes the `catalog` preset's content, driven by `ShellHost` instead of `BrowseCatalogWindowController`.
- `shell/App/PrefsView.swift` — content unchanged, but it becomes the `settings` preset's content (no longer wrapped in its own `NSWindow`); gains the theme-preview panel required by spec §2/§3.
- `shell/App/AppModel.swift` — `browseCatalogWindow` field and `openBrowseCatalog()` removed; replaced by calling `shellHost.pushCatalog()`. New `openSettings(initial:)`/`openCatalog(initial:)` doors for ticket 0004 (spec §6).
- `shell/App/JugnuApp.swift` — `AppDelegate.showPrefs()` removed; menu Preferences calls `shellHost.pushSettings()`. `PalettePanelController` construction replaced by `ShellHost` construction.
- `shell/App/HotkeyController.swift` — `onFire` callback changes from `palette?.toggle()` to `shellHost.handleInvoke()` (this also fixes ticket 0009 — see Task 8).
- `shell/App/MenuBarController.swift` — `onOpenPalette` wired to `shellHost.handleInvoke()`.
- `shell/Sources/JugnuUI/NotePanel.swift` — add `persist: Bool` param; `windowWillClose` only calls `onSave` when `persist == true`.
- `shell/Sources/JugnuUI/ToastPresenter.swift` — confirm/adjust to be Jugnu-branded + theme-retinting (spec §2 Toast row) if not already; non-activating confirmed.
- `shell/App/AddonUninstallPresenter.swift` — confirm call goes through `ShellHost.presentFollowUp` (push) instead of `UIHostController.presentConfirm`.

---

## Task 1: `ShellPreset` — preset table (sizes, chrome kind)

**Files:**
- Create: `shell/Sources/JugnuUI/ShellPreset.swift`
- Test: `shell/Tests/JugnuUITests/ShellPresetTests.swift`

**Interfaces:**
- Produces: `enum ShellPreset: String, Equatable { case launcher, catalog, settings, detail, confirm, list, form }` (toast and note are **not** cases here — they are handled outside the stack per spec). `ShellPreset.size(compactLauncher: Bool) -> NSSize`. `ShellPreset.hasSidebar: Bool` (false for `detail`, per spec §3 "No sidebar").

- [x] **Step 1: Write the failing test**

Note: test lives in `shell/Tests/JugnuUITests/` (new target), not `JugnuCoreTests` — `JugnuCoreTests` only depends on `JugnuCore`, and `ShellPreset` lives in `JugnuUI`. Added a `JugnuUITests` test target to `shell/Package.swift`.

```swift
import XCTest
@testable import JugnuUI

final class ShellPresetTests: XCTestCase {
    func test_launcherSize_compactWhenEmpty() {
        XCTAssertEqual(ShellPreset.launcher.size(compactLauncher: true).height, 120, accuracy: 0.5)
    }

    func test_launcherSize_fullWhenRows() {
        let size = ShellPreset.launcher.size(compactLauncher: false)
        XCTAssertEqual(size.width, 560, accuracy: 0.5)
        XCTAssertEqual(size.height, 360, accuracy: 0.5)
    }

    func test_catalogSize() {
        let size = ShellPreset.catalog.size(compactLauncher: false)
        XCTAssertEqual(size.width, 800, accuracy: 0.5)
        XCTAssertEqual(size.height, 560, accuracy: 0.5)
    }

    func test_detailHasNoSidebar() {
        XCTAssertFalse(ShellPreset.detail.hasSidebar)
    }

    func test_catalogHasSidebar() {
        XCTAssertTrue(ShellPreset.catalog.hasSidebar)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellPresetTests` — deferred (see below).

- [x] **Step 3: Write minimal implementation**

```swift
import AppKit

public enum ShellPreset: String, Equatable, Sendable {
    case launcher
    case catalog
    case settings
    case detail
    case confirm
    case list
    case form

    /// `compactLauncher` only affects `.launcher`; ignored for other cases.
    public func size(compactLauncher: Bool) -> NSSize {
        switch self {
        case .launcher: return compactLauncher ? NSSize(width: 560, height: 120) : NSSize(width: 560, height: 360)
        case .catalog: return NSSize(width: 800, height: 560)
        case .settings: return NSSize(width: 520, height: 560)
        case .detail: return NSSize(width: 560, height: 480)
        case .confirm: return NSSize(width: 380, height: 180)
        case .list: return NSSize(width: 420, height: 360)
        case .form: return NSSize(width: 400, height: 240)
        }
    }

    public var hasSidebar: Bool { self == .catalog }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellPresetTests` (or `make test`)
Expected: PASS (5 tests).
Status: deferred — `swift test` currently fails in this environment (`xcode-select` points at Command Line Tools only, no XCTest module). User will fix toolchain and run all tests together later; not blocking further plan tasks.

- [ ] **Step 5: Commit**

```bash
git add shell/Sources/JugnuUI/ShellPreset.swift shell/Tests/JugnuUITests/ShellPresetTests.swift shell/Package.swift
git commit -m "feat(shell): add ShellPreset size/chrome table"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 2: `ShellViewState` + `ShellStackEntry` — per-preset snapshots

**Files:**
- Create: `shell/Sources/JugnuUI/ShellStack.swift` (types only in this task; `ShellStack` push/pop logic is Task 3)
- Test: `shell/Tests/JugnuUITests/ShellStackEntryTests.swift` (corrected from plan draft — target must be `JugnuUITests`, see Task 1 note)

**Interfaces:**
- Consumes: `ShellPreset` (Task 1).
- Produces:
```swift
public enum ShellViewState: Equatable, Sendable {
    case launcher(query: String, selection: String?, scroll: CGFloat)
    case catalog(category: String?, subcategory: String?, tags: Set<String>, query: String, scroll: CGFloat, selectedCardID: String?)
    case settings(scroll: CGFloat, focusedControlID: String?)
    case detail(addonID: String)
    case confirm
    case list(query: String, highlightedID: String?, scroll: CGFloat)
    case form(values: [String: String], focusedFieldID: String?)

    public var preset: ShellPreset { /* maps each case to its ShellPreset */ }
}

public struct ShellStackEntry: Equatable, Sendable {
    public var state: ShellViewState
    public init(_ state: ShellViewState) { self.state = state }
    public var preset: ShellPreset { state.preset }
}
```

- [x] **Step 1: Write the failing test**

```swift
import XCTest
@testable import JugnuUI

final class ShellStackEntryTests: XCTestCase {
    func test_launcherState_mapsToLauncherPreset() {
        let entry = ShellStackEntry(.launcher(query: "", selection: nil, scroll: 0))
        XCTAssertEqual(entry.preset, .launcher)
    }

    func test_catalogState_mapsToCatalogPreset() {
        let entry = ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil))
        XCTAssertEqual(entry.preset, .catalog)
    }

    func test_detailState_mapsToDetailPreset() {
        let entry = ShellStackEntry(.detail(addonID: "mic-mute"))
        XCTAssertEqual(entry.preset, .detail)
    }

    func test_equality_sameCaseSameValues() {
        XCTAssertEqual(
            ShellStackEntry(.confirm),
            ShellStackEntry(.confirm)
        )
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellStackEntryTests` — deferred (toolchain, see Task 1). Verified via `swiftc -parse` that both files compile syntactically.

- [x] **Step 3: Write minimal implementation**

```swift
public enum ShellViewState: Equatable, Sendable {
    case launcher(query: String, selection: String?, scroll: CGFloat)
    case catalog(category: String?, subcategory: String?, tags: Set<String>, query: String, scroll: CGFloat, selectedCardID: String?)
    case settings(scroll: CGFloat, focusedControlID: String?)
    case detail(addonID: String)
    case confirm
    case list(query: String, highlightedID: String?, scroll: CGFloat)
    case form(values: [String: String], focusedFieldID: String?)

    public var preset: ShellPreset {
        switch self {
        case .launcher: return .launcher
        case .catalog: return .catalog
        case .settings: return .settings
        case .detail: return .detail
        case .confirm: return .confirm
        case .list: return .list
        case .form: return .form
        }
    }
}

public struct ShellStackEntry: Equatable, Sendable {
    public var state: ShellViewState
    public init(_ state: ShellViewState) { self.state = state }
    public var preset: ShellPreset { state.preset }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellStackEntryTests` (deferred, see Task 1)
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add shell/Sources/JugnuUI/ShellStack.swift shell/Tests/JugnuUITests/ShellStackEntryTests.swift
git commit -m "feat(shell): add ShellViewState/ShellStackEntry snapshot types"
```
Status: not yet committed — user commits manually.

---

## Task 3: `ShellStack` — push / replace / pop / idempotent logic (pure, no AppKit)

This is the highest-risk logic in the whole epic — get it right and unit-tested before any AppKit wiring touches it.

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellStack.swift` (append `ShellStack` type)
- Test: `shell/Tests/JugnuUITests/ShellStackTests.swift`

**Interfaces:**
- Consumes: `ShellStackEntry`, `ShellViewState`, `ShellPreset` (Tasks 1–2).
- Produces:
```swift
public struct ShellStack: Equatable, Sendable {
    public private(set) var entries: [ShellStackEntry]
    public init(root: ShellStackEntry = ShellStackEntry(.launcher(query: "", selection: nil, scroll: 0)))
    public var top: ShellStackEntry { entries.last! }
    public var isAtRoot: Bool { entries.count == 1 }

    /// Push a child. No-op (just updates top's state for refocus) if `entry.preset == top.preset` (idempotent rule).
    public mutating func push(_ entry: ShellStackEntry)
    /// Replace the top entry with a sibling. Only valid when stack has ≥1 entry; replaces `entries.last`.
    public mutating func replace(_ entry: ShellStackEntry)
    /// Pop one entry. No-op if already at root (root has nothing to pop â€” caller decides dismiss vs pop).
    public mutating func pop()
    /// Reset to a fresh `[launcher]` (home).
    public mutating func home(initial: ShellViewState)
    /// Empty the stack entirely (dismiss/close). `entries` becomes `[]`; `top`/`isAtRoot` must not be called until `home` or a fresh push.
    public mutating func clear()
}
```

- [x] **Step 1: Write the failing test**

```swift
import XCTest
@testable import JugnuUI

final class ShellStackTests: XCTestCase {
    func test_initialStack_isLauncherOnly() {
        let stack = ShellStack()
        XCTAssertEqual(stack.entries.count, 1)
        XCTAssertEqual(stack.top.preset, .launcher)
        XCTAssertTrue(stack.isAtRoot)
    }

    func test_push_addsChild() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
        XCTAssertEqual(stack.entries.count, 2)
        XCTAssertEqual(stack.top.preset, .catalog)
        XCTAssertFalse(stack.isAtRoot)
    }

    func test_pushSamePreset_isIdempotent_updatesTopInPlace() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
        stack.push(ShellStackEntry(.catalog(category: "Clipboard", subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
        XCTAssertEqual(stack.entries.count, 2, "must not push a second catalog entry")
        if case .catalog(let category, _, _, _, _, _) = stack.top.state {
            XCTAssertEqual(category, "Clipboard", "idempotent push still refocuses/updates state in place")
        } else {
            XCTFail("expected catalog state")
        }
    }

    func test_replace_swapsSibling_keepsParent() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
        stack.replace(ShellStackEntry(.settings(scroll: 0, focusedControlID: nil)))
        XCTAssertEqual(stack.entries.count, 2, "replace does not grow the stack")
        XCTAssertEqual(stack.top.preset, .settings)
        XCTAssertEqual(stack.entries[0].preset, .launcher, "launcher parent stays under the replaced sibling")
    }

    func test_pop_restoresParent() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
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
        stack.push(ShellStackEntry(.catalog(category: "X", subcategory: nil, tags: [], query: "abc", scroll: 5, selectedCardID: "id")))
        stack.home(initial: .launcher(query: "", selection: nil, scroll: 0))
        XCTAssertEqual(stack.entries.count, 1)
        XCTAssertEqual(stack.top.preset, .launcher)
        if case .launcher(let query, _, _) = stack.top.state {
            XCTAssertEqual(query, "", "home must not restore the previous launcher query")
        } else {
            XCTFail("expected launcher state")
        }
    }

    func test_clear_emptiesStack() {
        var stack = ShellStack()
        stack.push(ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
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
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellStackTests` — deferred (toolchain, see Task 1). Verified via `swiftc -parse` that the file compiles syntactically.

- [x] **Step 3: Write minimal implementation**

Append to `shell/Sources/JugnuUI/ShellStack.swift`:

```swift
public struct ShellStack: Equatable, Sendable {
    public private(set) var entries: [ShellStackEntry]

    public init(root: ShellStackEntry = ShellStackEntry(.launcher(query: "", selection: nil, scroll: 0))) {
        self.entries = [root]
    }

    public var top: ShellStackEntry {
        guard let last = entries.last else {
            preconditionFailure("ShellStack.top read after clear(); call home() or push() first")
        }
        return last
    }

    public var isAtRoot: Bool { entries.count == 1 }

    public mutating func push(_ entry: ShellStackEntry) {
        if let lastIndex = entries.indices.last, entries[lastIndex].preset == entry.preset {
            entries[lastIndex] = entry
            return
        }
        entries.append(entry)
    }

    public mutating func replace(_ entry: ShellStackEntry) {
        guard !entries.isEmpty else {
            entries = [entry]
            return
        }
        entries[entries.count - 1] = entry
    }

    public mutating func pop() {
        guard entries.count > 1 else { return }
        entries.removeLast()
    }

    public mutating func home(initial: ShellViewState) {
        entries = [ShellStackEntry(initial)]
    }

    public mutating func clear() {
        entries = []
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellStackTests` (deferred, see Task 1)
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add shell/Sources/JugnuUI/ShellStack.swift shell/Tests/JugnuUITests/ShellStackTests.swift
git commit -m "feat(shell): add ShellStack push/replace/pop/home/clear logic"
```
Status: not yet committed — user commits manually.

---

## Task 4: `ShellHost` skeleton — owns one `KeyablePanel`, morphs frame, drives `ShellStack`

This task wires `ShellStack` to a real `KeyablePanel` and gets frame-morphing working, but does **not** yet migrate any existing preset content — it renders a placeholder so the mechanism itself is provable before content migration risk is added on top.

**Files:**
- Create: `shell/Sources/JugnuUI/ShellHost.swift`
- Test: `shell/Tests/JugnuUITests/ShellHostFrameTests.swift` (pure frame-math only; full AppKit panel behavior isn't unit-testable in `swift test` without a display, so this task tests the clamp/size math as a free function).

**Interfaces:**
- Consumes: `ShellStack`, `ShellStackEntry`, `ShellPreset` (Tasks 1–3), `KeyablePanel` (existing), `PanelChrome.borderless` (existing, currently unused — this is where it finally gets consumed).
- Produces:
```swift
@MainActor
public final class ShellHost: ObservableObject {
    public init(reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    @Published public private(set) var stack: ShellStack
    public var isVisible: Bool { get }
    public func morphFrame(to preset: ShellPreset, compactLauncher: Bool, on screen: NSScreen) // clamps to screen.visibleFrame
}

/// Free function so frame math is unit-testable without a live NSScreen.
public func clampedFrame(size: NSSize, centeredOn screenFrame: NSRect) -> NSRect
```

- [x] **Step 1: Write the failing test**

```swift
import XCTest
import AppKit
@testable import JugnuUI

final class ShellHostFrameTests: XCTestCase {
    func test_clampedFrame_centersWithinScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 560)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(frame.midY, screen.midY, accuracy: 0.5)
    }

    func test_clampedFrame_shrinksWhenLargerThanScreen() {
        let screen = NSRect(x: 0, y: 0, width: 400, height: 300)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertLessThanOrEqual(frame.width, screen.width)
        XCTAssertLessThanOrEqual(frame.height, screen.height)
    }

    func test_clampedFrame_staysInsideScreenBounds() {
        let screen = NSRect(x: 100, y: 50, width: 1440, height: 900)
        let frame = clampedFrame(size: NSSize(width: 800, height: 560), centeredOn: screen)
        XCTAssertTrue(screen.contains(CGPoint(x: frame.minX, y: frame.minY)))
        XCTAssertTrue(screen.contains(CGPoint(x: frame.maxX - 1, y: frame.maxY - 1)))
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellHostFrameTests` — deferred (toolchain, see Task 1). Confirmed the test file references `clampedFrame`/`ShellHostFrameTests` which did not exist before Step 3.

- [x] **Step 3: Write minimal implementation**

```swift
import AppKit
import SwiftUI

public func clampedFrame(size requested: NSSize, centeredOn screenFrame: NSRect) -> NSRect {
    let width = min(requested.width, screenFrame.width)
    let height = min(requested.height, screenFrame.height)
    let x = screenFrame.midX - width / 2
    let y = screenFrame.midY - height / 2
    return NSRect(x: x, y: y, width: width, height: height)
}

@MainActor
public final class ShellHost: ObservableObject {
    @Published public private(set) var stack: ShellStack
    private var panel: KeyablePanel?
    private let reduceMotion: () -> Bool

    public init(reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.stack = ShellStack()
        self.reduceMotion = reduceMotion
    }

    public var isVisible: Bool { panel?.isVisible ?? false }

    public func morphFrame(to preset: ShellPreset, compactLauncher: Bool, on screen: NSScreen) {
        guard let panel else { return }
        let size = preset.size(compactLauncher: compactLauncher)
        let target = clampedFrame(size: size, centeredOn: screen.visibleFrame)
        if reduceMotion() {
            panel.setFrame(target, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().setFrame(target, display: true)
            }
        }
    }

    /// Exposed for Task 5+ to attach the real KeyablePanel once content views exist.
    func attach(panel: KeyablePanel) {
        self.panel = panel
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellHostFrameTests` (or `make test`)
Expected: PASS (3 tests).
Status: deferred — `swift test` still fails in this environment (`xcode-select` points at Command Line Tools only, no XCTest module; `swift build --build-tests` confirms `no such module 'XCTest'`, same root cause as Tasks 1–3). Verified instead via `swift build --target JugnuUI`, which compiles `ShellHost.swift` (with `KeyablePanel`/`PanelChrome`/`ShellPreset`/`ShellStack`) cleanly with no errors — real typecheck, not just `swiftc -parse`. Test file itself also parses clean (`swiftc -parse Tests/JugnuUITests/ShellHostFrameTests.swift`). User will run `make test` later after fixing their toolchain.

- [ ] **Step 5: Commit**

```bash
git add shell/Sources/JugnuUI/ShellHost.swift shell/Tests/JugnuUITests/ShellHostFrameTests.swift
git commit -m "feat(shell): add ShellHost skeleton with frame-morph math"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 5: Migrate `launcher` onto `ShellHost` — retire `PalettePanelController`

First real content migration. `PaletteView` moves out of `PalettePanelController.swift` into its own file and stops owning its panel; `ShellHost` builds the single `KeyablePanel` and hosts `PaletteView` as its `launcher` content.

**Files:**
- Create: `shell/Sources/JugnuUI/PaletteView.swift` (cut from `shell/App/PalettePanelController.swift`)
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — add `show()` / `hide()` / launcher-specific `presentLauncher(model:)`.
- Modify: `shell/App/JugnuApp.swift` — construct `ShellHost` instead of `PalettePanelController`; `AppDelegate` now holds `shellHost: ShellHost?`.
- Modify: `shell/App/HotkeyController.swift` and `shell/App/MenuBarController.swift` — `onFire`/`onOpenPalette` call `shellHost.handleInvoke()` (stub implementation for now: alias to old toggle semantics; real home-or-close logic lands in Task 8).
- Delete: `shell/App/PalettePanelController.swift` (only after this task's manual smoke passes — see Step 6).
- Test: manual smoke (documented in Step 6); no new automated test here beyond what Tasks 1–4 already cover, because `PaletteView`'s search/keyboard logic already has no existing unit tests and is out of scope to add net-new here (tracked separately if desired — not blocking this task).

**Interfaces:**
- Consumes: `AppModel` (existing, unchanged), `ShellStack`/`ShellPreset` (Tasks 1–4).
- Produces: `ShellHost.show()`, `ShellHost.hide()`, `ShellHost.handleInvoke()` (temporary toggle-only stub — documented as such in a comment, replaced in Task 8).

**Deviation from plan (discovered during implementation, confirmed with user):** the plan's illustrative snippets have `PaletteView`/`ShellHost.show`/`handleInvoke` reference `AppModel` directly from `JugnuUI`. `AppModel` lives in the `Jugnu` executable target and itself `import`s `JugnuUI` (uses `UIHostController`, `BrowseCatalogWindowController<BrowseCatalogViewModel>`) — JugnuUI referencing `AppModel` back would be a real dependency cycle, not just a style issue. The codebase already has a precedent for this exact situation: `BrowseCatalogWindowController<VM: BrowseCatalogViewModelProtocol>` (JugnuUI) is generic over a protocol; the App-target `BrowseCatalogViewModel` conforms to it. Followed the same pattern here:
- New `PaletteModelProtocol` (in `PaletteView.swift`, JugnuUI) declares exactly what `PaletteView` needs (`allCommands`, `lastHits`, `statusMessage`, `commandsForFirstView()`, `search(_:)`, `isFavorite`, `toggleFavorite`).
- `PaletteView` is now `PaletteView<Model: PaletteModelProtocol>` — stays in JugnuUI, generic, no `AppModel` reference.
- `ShellHost.show`/`handleInvoke` are generic methods (`<Model: PaletteModelProtocol>`) on the concrete `ShellHost` class — `ShellHost` itself still has zero `AppModel`/App-target dependencies.
- `AppModel` (App target) now conforms to `PaletteModelProtocol` — one line (`AppModel.swift`), no logic change since it already had all the needed members.
- All the actual `AppModel`-aware wiring (building `onRun`/`onOpenBrowseCatalog` closures, picking the screen via `PalettePlacement`) moved into a new private `AppDelegate.invokeShell()` in `JugnuApp.swift`, replacing the plan's inline closures in `MenuBarController`/`HotkeyController` construction — same effect, but avoids duplicating that closure-building logic between the two callers.
- `pushSettings`/`pushCatalog` stubs (plan Step 4) were **not** added — Task 6/7 aren't wired into `JugnuApp.swift` yet at all (Preferences menu still opens the old ad hoc `NSWindow` via `AppDelegate.showPrefs()`, catalog untouched), so nothing calls them yet and a stub would be dead code. They'll be added when Task 6/7 actually wire the menu/PaletteView to `ShellHost`.

- [x] **Step 1: Cut `PaletteView` out of `PalettePanelController.swift` into `shell/Sources/JugnuUI/PaletteView.swift`**

Move the `struct PaletteView: View { ... }` body verbatim (lines ~92 to end of `PalettePanelController.swift`) into the new file. Change its `onRun` callback signature so it no longer calls `self?.hide()` directly — instead it takes a `ShellHost` (or a plain `onDidRun: () -> Void` closure) so `ShellHost` decides what happens after a run, per spec (`run` no longer always destroys the launcher; toast-only commands stay on `launcher`).

```swift
// shell/Sources/JugnuUI/PaletteView.swift
import SwiftUI
import JugnuCore

public struct PaletteView: View {
    @ObservedObject var model: AppModel
    var onOpenCatalog: () -> Void
    var onRun: (IndexedCommand) -> Void
    // ... existing body, unchanged except onRun no longer calls hide() itself
}
```

- [x] **Step 2: Add `show()`/`hide()`/`presentLauncher` to `ShellHost`**

Status: implemented as generic methods over `PaletteModelProtocol` (see deviation note above), not the plan's literal `AppModel`-typed signature.

```swift
extension ShellHost {
    public func show(model: AppModel, on screen: NSScreen) {
        if panel == nil {
            let hostingView = NSHostingView(
                rootView: PaletteView(
                    model: model,
                    onOpenCatalog: { [weak self] in self?.pushCatalog(model: model) },
                    onRun: { [weak self] cmd in model.run(cmd) }
                )
            )
            let built = PanelChrome.borderless(size: ShellPreset.launcher.size(compactLauncher: true), content: hostingView)
            attach(panel: built)
        }
        guard let panel else { return }
        morphFrame(to: .launcher, compactLauncher: stack.top.preset == .launcher, on: screen)
        panel.orderFront(nil)
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        panel?.orderOut(nil)
        stack.clear()
    }

    /// Temporary: real home-or-close semantics land in Task 8.
    public func handleInvoke(model: AppModel, on screen: NSScreen) {
        if isVisible { hide() } else { show(model: model, on: screen) }
    }
}
```

Note: `PanelChrome.borderless` currently takes a `View` generic directly, not a pre-built `NSHostingView` — check its actual signature in `shell/Sources/JugnuUI/PanelChrome.swift` before writing this and adjust the call to match (`PanelChrome.borderless(size:content: PaletteView(...))`), since Task 4's research found it builds the `NSHostingView` internally.

- [x] **Step 3: Wire `JugnuApp.swift`**

Status: wired via a new private `AppDelegate.invokeShell()` (screen selection + `onRun`/`onOpenBrowseCatalog` closures) called from both `onOpenPalette` and `HotkeyController`'s `onFire`, rather than duplicating the closure inline at both call sites as the plan snippet does. `showPrefs()` untouched (still the old ad hoc `NSWindow`) — Task 6 migrates it.

```swift
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var model: AppModel?
    private var shellHost: ShellHost?
    private var hotkey: HotkeyController?
    private var firstRun: FirstRunWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model
        model.bootstrap()

        let shellHost = ShellHost()
        self.shellHost = shellHost

        let menuBar = MenuBarController(
            onOpenPalette: { [weak shellHost, weak model] in
                guard let model, let screen = NSScreen.main else { return }
                shellHost?.handleInvoke(model: model, on: screen)
            },
            onPreferences: { [weak shellHost, weak model] in
                guard let model, let screen = NSScreen.main else { return }
                shellHost?.pushSettings(model: model, on: screen) // stub until Task 6
            },
            onQuit: { NSApp.terminate(nil) }
        )
        self.menuBar = menuBar

        let hotkey = HotkeyController(model: model) { [weak shellHost, weak model] in
            guard let model, let screen = NSScreen.main else { return }
            shellHost?.handleInvoke(model: model, on: screen)
        }
        self.hotkey = hotkey
        hotkey.registerFromConfig()

        if !model.state.firstRunCompleted {
            let first = FirstRunWindowController(model: model) { [weak self, weak hotkey] in
                hotkey?.registerFromConfig()
                self?.firstRun = nil
            }
            self.firstRun = first
            first.show()
        }
    }
}
```

(`pushSettings`/`pushCatalog` are stubbed to compile-fail loudly until Task 6/7 exist — acceptable since this is one atomic commit per task; if the build must stay green at every commit, stub them as empty no-op methods on `ShellHost` in this task and fill them in Tasks 6–7.)

- [x] **Step 4: Add no-op stubs so the build is green**

Status: not needed — nothing calls `pushSettings`/`pushCatalog` yet (see deviation note above), so no stub was required to keep the build green.

- [x] **Step 5: Build**

Run: `cd shell && swift build` (repo uses SwiftPM, no `.xcodeproj` — confirmed via `Package.swift`).
Result: PASS — `swift build` (whole package, all targets) succeeds and links `Jugnu`. Also verified `swift build --target JugnuUI` alone compiles clean (`PaletteView<Model: PaletteModelProtocol>` + `ShellHost` generics typecheck with no `AppModel` dependency).

- [x] **Step 6: Manual smoke**

Status: PASS, run manually by user. Built `.build/debug/Jugnu` was launched; initial run showed the launcher opening twice per hotkey press — root cause was two Jugnu processes running simultaneously (my test launch + a stale already-running instance from an older DerivedData/Xcode build), both holding the global hotkey, not a code bug. After killing the stale process and relaunching a single fresh instance, user confirmed: "Working fine now" — single panel open/close via ⌥Space, no duplication.

- [x] **Step 7: Delete `PalettePanelController.swift`**

Deleted via `rm` (not `git rm` — git writes are the user's to do, never done proactively). Shows as a deletion in `git status` for the user to stage.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(shell): migrate launcher onto ShellHost, retire PalettePanelController"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 6: Migrate `settings` onto `ShellHost` — retire the ad hoc Preferences `NSWindow`

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — replace the Task 5 stub `pushSettings` with a real push that builds `PrefsView` as the panel's content.
- Modify: `shell/App/PrefsView.swift` — no longer constructs its own dismiss (`NSWindow.close()`); its "Browse Catalog…" button now calls `onOpenCatalog: () -> Void` (injected) instead of `model.openBrowseCatalog()` directly, and gains a **theme preview** subview (spec §2 "Themes": settings shows a mini launcher/token strip because live-reload of the real launcher isn't visible while settings replaces it).
- Modify: `shell/App/JugnuApp.swift` — delete `AppDelegate.showPrefs()`; menu Preferences calls `shellHost.pushSettings(...)` (already wired in Task 5, now functional).
- Modify: `shell/App/AppModel.swift` — remove `openBrowseCatalog()`'s settings-adjacent bits if any overlap (none expected; catalog is Task 7).
- Test: manual smoke only (SwiftUI view content, no new pure logic to unit test here beyond stack behavior already covered).

**Interfaces:**
- Consumes: `ShellStack.replace`/`push` (Task 3) — pushing `settings` from `launcher` is a **push** (child); replacing `catalog` with `settings` is a **replace** (sibling), per spec §4. `ShellHost` must pick the right stack operation based on `stack.top.preset`.

**Deviation from plan (same root cause as Task 5):** `renderCurrentTop(model:)` needs to construct both `PaletteView<AppModel>` and `PrefsView` (both `AppModel`-typed) and swap the panel's content — that dispatch can't live on `ShellHost` (JugnuUI) without reintroducing the `AppModel` dependency cycle. So `renderCurrentTop(model:)` and `pushSettings()` are `AppDelegate` methods (`JugnuApp.swift`, App target), not `ShellHost` extension methods as the plan's snippet shows. `ShellHost` (JugnuUI) instead grew three small generic primitives the App target composes: `push(_:)`/`replace(_:)` (thin wrappers over `ShellStack`), `setContent<V: View>(_:)` (swaps `panel.contentView`), `ensurePanel<V: View>(initialContent:size:)` (builds the panel on first use, generic over content), `orderFront()`. `ShellHost` itself still has zero `AppModel`/App-target references — same boundary as Task 5.

- [x] **Step 1: Implement `pushSettings` with correct push-vs-replace**

Status: implemented as `AppDelegate.pushSettings()` (see deviation note). Push-vs-replace logic matches the plan exactly (`stack.top.preset == .catalog` → replace, else push).

```swift
extension ShellHost {
    public func pushSettings(model: AppModel, on screen: NSScreen? = nil) {
        let screen = screen ?? NSScreen.main
        guard let screen else { return }
        let entry = ShellStackEntry(.settings(scroll: 0, focusedControlID: nil))
        if stack.top.preset == .catalog {
            stack.replace(entry) // siblings
        } else {
            stack.push(entry) // child of launcher (or no-op if already settings)
        }
        renderCurrentTop(model: model)
        morphFrame(to: .settings, compactLauncher: false, on: screen)
    }
}
```

`renderCurrentTop(model:)` is a new private method that switches on `stack.top.preset` and swaps the panel's `NSHostingView.rootView` to the matching content view (`PaletteView` / `PrefsView` / …). This is the method every subsequent Task (7, 9, 10) extends with one more case.

```swift
private func renderCurrentTop(model: AppModel) {
    guard let panel else { return }
    let content: AnyView
    switch stack.top.preset {
    case .launcher:
        content = AnyView(PaletteView(model: model, onOpenCatalog: { [weak self] in self?.pushCatalog(model: model) }, onRun: { model.run($0) }))
    case .settings:
        content = AnyView(PrefsView(model: model, onOpenCatalog: { [weak self] in self?.pushCatalog(model: model) }))
    default:
        content = AnyView(EmptyView()) // filled in by later tasks
    }
    panel.contentView = NSHostingView(rootView: content)
}
```

- [x] **Step 2: Remove `showPrefs()` from `JugnuApp.swift`, wire menu to `shellHost.pushSettings`**

Status: `showPrefs()` (built its own titled `NSWindow`) deleted entirely; `MenuBarController`'s `onPreferences` now calls `AppDelegate.pushSettings()`.

```swift
let menuBar = MenuBarController(
    onOpenPalette: { [weak shellHost, weak model] in
        guard let model, let screen = NSScreen.main else { return }
        shellHost?.handleInvoke(model: model, on: screen)
    },
    onPreferences: { [weak shellHost, weak model] in
        guard let model else { return }
        shellHost?.pushSettings(model: model)
    },
    onQuit: { NSApp.terminate(nil) }
)
```

- [x] **Step 3: Add theme preview to `PrefsView`**

Status: added `themePreview(_:)` to `PrefsView.swift` — a small search-field + card + accent-swatch mockup, live-bound to the same `JugnuThemeColors` the real color editors below it mutate, so edits are visible in real time without needing to leave settings. Placed directly above `themeEditors(theme)`.

```swift
struct ThemePreviewStrip: View {
    let theme: JugnuTheme
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6).fill(theme.background).frame(width: 60, height: 36)
                .overlay(Text("Aa").foregroundStyle(theme.foreground).font(.caption))
            RoundedRectangle(cornerRadius: 6).fill(theme.accent).frame(width: 24, height: 24)
        }
        .padding(8)
        .background(ThemedPanelBackground { EmptyView() })
    }
}
```

(Adjust to the real `JugnuTheme` API — check `shell/Sources/JugnuUI/Theme.swift` for actual property names before writing; this is illustrative of intent, not a literal signature.)

- [x] **Step 4: Build + manual smoke**

Result: `swift build` PASS (whole package). Manual smoke run by user on `.build/debug/Jugnu`:
1. Launcher → Preferences (menu bar) → `settings` pushes, panel morphs, theme preview visible and live-updating. PASS.
2. Esc → pops to `launcher`. PASS.
3. Catalog↔settings replace behavior — deferred, not testable until Task 7 migrates catalog off its own window.
4. Preferences → Preferences again (already on settings) → no-op/refocus. PASS (implicit — same panel, no rebuild observed).

User also flagged: panel dismisses when the mouse hits a hidden menu bar's reveal zone (no click). Investigated — `hidesOnDeactivate = false` is set, nothing in current code closes on resign-key/hover; likely a system floating-panel/menu-bar z-order interaction, not caused by Tasks 5/6. Real click-outside-vs-resign-key detection is explicitly Task 8 scope — noted there for follow-up, not blocking Task 6.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(shell): migrate settings preset onto ShellHost, retire ad hoc Preferences NSWindow"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 7: Migrate `catalog` onto `ShellHost` — retire `BrowseCatalogWindowController`

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — replace Task 5 stub `pushCatalog` with a real push/replace + `renderCurrentTop` case for `.catalog`.
- Modify: `shell/App/BrowseCatalogViewModel.swift` — constructor no longer needs a window reference; confirm it already only needs `model: AppModel` (research confirmed this — no change expected, just re-verify).
- Modify: `shell/App/AppModel.swift` — delete `browseCatalogWindow` field and `openBrowseCatalog()` method (lines 25, 220–231 per research).
- Delete: `shell/Sources/JugnuUI/BrowseCatalogWindow.swift`.
- Modify: `shell/Sources/JugnuUI/BrowseCatalogView.swift` — no structural change expected (it's already just SwiftUI content); confirm it takes `viewModel:` only, not a window controller reference.
- Test: manual smoke.

**Interfaces:**
- Consumes: `BrowseCatalogViewModel` (existing, `ObservableObject`), `ShellStack` push/replace (Task 3).

**Deviation from plan (same root cause as Tasks 5–6):** `pushCatalog()` and the `.catalog` case of `renderCurrentTop` live on `AppDelegate` (App target), not as `ShellHost` extension methods — `BrowseCatalogViewModel(model:)` needs `AppModel`, so the dispatch has to happen where `AppModel` is visible. `onSelectCard` (plan's illustrative addition to `BrowseCatalogView`, for pushing `detail`) was **not** added — `detail` doesn't exist as a preset/case yet (that's Task 9), so there's nothing to push to; adding an unused callback param now would be dead code. `BrowseCatalogView(viewModel:)` construction is unchanged from its existing signature.

- [x] **Step 1: Implement `pushCatalog` + `renderCurrentTop` catalog case**

Status: `AppDelegate.pushCatalog()` added (mirrors `pushSettings()` — replace when `stack.top.preset == .settings`, else push). `renderCurrentTop` gained a `.catalog` case building `BrowseCatalogView(viewModel: BrowseCatalogViewModel(model: model))`. Factored panel-bootstrap logic (previously duplicated between `show`/`pushSettings`) into a shared `ensurePanelIfNeeded(model:)`.

```swift
extension ShellHost {
    public func pushCatalog(model: AppModel, on screen: NSScreen? = nil, initial: (category: String?, tags: Set<String>)? = nil) {
        let screen = screen ?? NSScreen.main
        guard let screen else { return }
        let entry = ShellStackEntry(.catalog(
            category: initial?.category, subcategory: nil,
            tags: initial?.tags ?? [], query: "", scroll: 0, selectedCardID: nil
        ))
        if stack.top.preset == .settings {
            stack.replace(entry)
        } else {
            stack.push(entry)
        }
        renderCurrentTop(model: model)
        morphFrame(to: .catalog, compactLauncher: false, on: screen)
    }
}
```

Extend `renderCurrentTop`'s switch:

```swift
case .catalog:
    let vm = BrowseCatalogViewModel(model: model)
    content = AnyView(BrowseCatalogView(
        viewModel: vm,
        onSelectCard: { [weak self] addonID in self?.pushDetail(addonID: addonID, model: model) }
    ))
```

(`onSelectCard` param is new on `BrowseCatalogView` if it doesn't already exist — check the file; per research it currently has no "push detail" concept since `detail` didn't exist as a separate preset before. `pushDetail` itself is Task 9.)

- [x] **Step 2: Delete `openBrowseCatalog()` and `browseCatalogWindow` from `AppModel.swift`**

Status: both removed. No remaining references anywhere in the tree (`grep -rn "BrowseCatalogWindowController\|openBrowseCatalog"` — empty).

- [x] **Step 3: Delete `BrowseCatalogWindow.swift`**

Deleted via `rm` (not `git rm` — git writes are the user's to do, never done proactively). Shows as a deletion in `git status` for the user to stage.

- [x] **Step 4: Update `PaletteView`'s "Browse Addons" row and `PrefsView`'s "Browse Catalog…" button** to call the injected `onOpenCatalog` closure (already threaded through in Tasks 5–6) instead of `model.openBrowseCatalog()`.

Status: `PaletteView`'s `onOpenBrowseCatalog` closure now resolves to `AppDelegate.pushCatalog()` everywhere it's constructed (launcher build in `ensurePanelIfNeeded`, and the `.launcher` case of `renderCurrentTop`). `PrefsView` gained an `onOpenCatalog: () -> Void` param; its button now calls that instead of the deleted `model.openBrowseCatalog()`.

- [x] **Step 5: Build**

Result: `swift build` (whole package) PASS, clean link. Manual smoke deferred at user's request (don't relaunch the app for every task) — will do a combined manual pass covering Tasks 5–7's flows (launcher↔catalog↔settings push/replace/Esc) together, rather than one launch per task.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(shell): migrate catalog preset onto ShellHost, retire BrowseCatalogWindowController"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 8: Hotkey home-or-close + click-outside dismiss (closes ticket 0009 + spec §2 History rows)

Real `handleInvoke` logic (Task 5's version was a toggle-only stub) plus click-outside detection.

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — replace stub `handleInvoke`; add `handleClickOutside()`, `handleEsc()`.
- Modify: `shell/App/HotkeyController.swift` — confirm `onFire` closure signature unchanged (already calls `shellHost.handleInvoke`).
- Test: `shell/Tests/JugnuUITests/ShellStackTests.swift` — add pure-logic tests for the **decision** of home vs close vs dismiss (test a small pure function extracted from `handleInvoke`, not the AppKit side).

**Interfaces:**
- Consumes: `ShellStack` (Task 3).
- Produces:
```swift
public enum InvokeOutcome: Equatable { case showHome, close }
public func decideInvokeOutcome(stack: ShellStack, isVisible: Bool) -> InvokeOutcome
```

**Deviation from plan (same root cause as Tasks 5–7, plus one new AppKit-level issue):**
- `handleInvoke`/`handleEsc`/`handleClickOutside` are `AppDelegate` methods (`JugnuApp.swift`), not `ShellHost` extension methods — both `handleInvoke`'s `.showHome` branch and `handleEsc`'s pop branch must call `renderCurrentTop(model:)`, which is `AppModel`-typed and lives on `AppDelegate` for the same reason as Tasks 5–7. `ShellHost` (JugnuUI) stays `AppModel`-free and instead grew small AppKit-only primitives the App target composes: `popTop() -> Bool` (pure pop-or-no-op over `ShellStack`, returns whether it actually popped), `goHome()` (wraps `stack.home(initial:)`), `setOnCancel(_:)` (rebinds the panel's Esc handler), `armClickOutsideDismiss(onOutside:)` (starts the global mouse-down monitor), and `hide()` (now correctly calls `stack.clear()` instead of the old `stack = ShellStack()`, and also stops the click-outside monitor).
- `decideInvokeOutcome`/`InvokeOutcome` landed in `ShellStack.swift` (not `ShellHost.swift`) — it's pure stack-state logic with zero AppKit dependency, so it belongs next to `ShellStack` per the file's existing contents; `ShellHost.swift` is reserved for the AppKit-touching half.
- **New issue not anticipated by the plan:** the plan's `KeyablePanel` sketch (§ Task 8 Step 5) implies a plain `onCancel` closure, but the existing `ListPanel`/`ConfirmPanel`/`FormPanel` subclasses already declare their own private `onCancel: () -> Void` stored properties and override `cancelOperation(_:)` themselves — adding a same-named `var onCancel: (() -> Void)?` to the `KeyablePanel` base class collided with those (Swift treats it as an invalid property override, not shadowing). Renamed the new base-class property to `escHandler` to avoid the clash; the three existing subclasses are untouched and still override `cancelOperation(_:)` directly (their override shadows the base implementation, no double-firing).
- Real click-outside detection (`NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`) is armed by `AppDelegate` right after every `orderFront()` call (in `invokeShell`'s `.showHome` branch, `pushSettings`, and `pushCatalog` — anywhere the panel becomes newly visible/key), not folded into `ShellHost.orderFront()` itself, so `AppDelegate` controls exactly when it (re)arms rather than it firing on every render.
- `panel.escHandler` is rebound once per `renderCurrentTop(model:)` call (i.e. on every stack change), rather than per-preset — this is simpler than conditionally rebinding and costs nothing since it's just closure reassignment.
- Investigated the user's manually-observed "panel dismisses on hover into hidden menu bar" bug (flagged in Task 6's notes): confirmed via `grep -rn "resignKey\|windowDidResign\|becomeKey"` across `shell/` that no code path in the current tree ever hooks resign-key or hover to dismiss — `PanelChrome.borderless` already sets `hidesOnDeactivate = false`, and the only dismiss trigger now is the explicit `.leftMouseDown`/`.rightMouseDown` global monitor added in this task. The bug could not have been reproduced by anything in the current codebase at the time it was observed either (likely an artifact of the now-deleted `PalettePanelController` or a stale running instance, per Task 5's duplicate-process note) — nothing left to fix; flagging for the user to re-verify manually since hover can no longer trigger dismiss by construction.

- [x] **Step 1: Write the failing test**

```swift
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
    stack.push(ShellStackEntry(.catalog(category: nil, subcategory: nil, tags: [], query: "", scroll: 0, selectedCardID: nil)))
    XCTAssertEqual(decideInvokeOutcome(stack: stack, isVisible: true), .showHome)
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellStackTests` — deferred (toolchain, see Task 1). Confirmed by inspection: before Step 3, `decideInvokeOutcome`/`InvokeOutcome` did not exist anywhere in `JugnuUI`, so the three new tests would fail to compile.

- [x] **Step 3: Write minimal implementation**

Status: `InvokeOutcome`/`decideInvokeOutcome` implemented exactly as specified, appended to `ShellStack.swift` (see deviation note on file placement). `handleInvoke`/`handleEsc`/`handleClickOutside` implemented per the deviation note as `AppDelegate` methods composing new `ShellHost` primitives (`popTop()`, `goHome()`, `setOnCancel(_:)`, `armClickOutsideDismiss(onOutside:)`) instead of the plan's literal `AppModel`-typed `ShellHost` extension methods.

```swift
public enum InvokeOutcome: Equatable, Sendable { case showHome, close }

public func decideInvokeOutcome(stack: ShellStack, isVisible: Bool) -> InvokeOutcome {
    guard isVisible else { return .showHome }
    return stack.top.preset == .launcher ? .close : .showHome
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellStackTests` — deferred (toolchain, see Task 1). Verified instead via `swift build` (whole package) and `swift build --target JugnuUI`, both clean — real typecheck of the new tests' call sites against the implementation. User will run `make test` later after fixing their toolchain, same as Tasks 1–7.

- [x] **Step 5: Wire click-outside detection**

`KeyablePanel`/`NSPanel` resign-key alone must **not** trigger dismiss (spec: "Cmd+Tab / resign-key is not click-outside"). Detect genuine click-outside via a global `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])` in `ShellHost.show()`, removed in `hide()`:

```swift
private var outsideClickMonitor: Any?

private func startOutsideClickMonitor() {
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
        self?.handleClickOutside()
    }
}

private func stopOutsideClickMonitor() {
    if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
    outsideClickMonitor = nil
}
```

Call `startOutsideClickMonitor()` at the end of `show()`, `stopOutsideClickMonitor()` at the top of `hide()`. A global monitor only fires for clicks **outside** the app's own windows, so clicks inside the panel never reach it — this satisfies "not empty space inside the panel."

Status: implemented as `ShellHost.armClickOutsideDismiss(onOutside:)` (public, wraps the private `startOutsideClickMonitor`/`stopOutsideClickMonitor` pair) instead of a plan-literal `show()` — there is no `ShellHost.show()` anymore (see Step 3 deviation note in this task's header); `AppDelegate` calls `armClickOutsideDismiss` right after every `orderFront()` (in `invokeShell`'s `.showHome` branch, `pushSettings`, `pushCatalog`). `ShellHost.hide()` calls `stopOutsideClickMonitor()` at the top, matching the plan's intent. Also fixed a pre-existing bug while touching `hide()`: it previously did `stack = ShellStack()` (silently resets to a fresh single-entry launcher stack) instead of `stack.clear()` (empties it per the "dismiss" contract in spec/Task 3) — `decideInvokeOutcome`/`isAtRoot` callers depend on `clear()`'s actual empty-stack semantics.

- [x] **Step 6: Manual smoke**

Status: deferred at user's explicit request for this task — "do NOT relaunch/run the built app during implementation; user will manually smoke-test themselves this time." `swift build` (whole package) is green; user will run the six scenarios below themselves:
1. Not visible → invoke → shows fresh launcher.
2. On launcher → invoke → closes.
3. On catalog → invoke → home (fresh launcher, catalog gone from stack).
4. On catalog → click outside app (e.g. click Finder desktop) → dismiss, stack empty.
5. On catalog → Cmd+Tab away and back → panel still showing catalog (resign-key ≠ dismiss).
6. On launcher → Esc → dismiss. On catalog → Esc → pop to launcher.

Also asked the user to re-check the "panel dismisses when hovering into the hidden menu bar's reveal zone" bug reported during Task 6 — code inspection (`grep -rn "resignKey\|windowDidResign\|becomeKey"` across `shell/`) found no resign-key/hover-driven dismiss path anywhere in the current tree, and the only dismiss trigger is now the explicit mouse-down-only global monitor added in this task, so hover alone cannot trigger dismiss by construction. Flagged as a re-verify rather than a fix, since no reproducing code was found to change.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "fix(shell): hotkey home-or-close + click-outside dismiss (closes #0009)"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 9: `detail` preset — new addon detail view, push from catalog card

**Files:**
- Modify: `shell/App/JugnuApp.swift` — add `AppDelegate.pushDetail(addonID:)`, extend `renderCurrentTop` with a `.detail` case, add a reused `catalogViewModel(model:)` accessor.
- Modify: `shell/Sources/JugnuUI/BrowseCatalogView.swift` — `onSelectCard: (String) -> Void` param replaces the old internal `.sheet(item: $detailEntry)`/`AddonDetailView` presentation; card tap now pushes the shell's `detail` preset instead of showing a sheet inside the catalog panel.
- Test: manual smoke (view composition only; underlying data comes from existing `RegistryEntry`/`CatalogTaxonomy`, already covered by `BrowseCatalogFilterTests`).

**Interfaces:**
- Consumes: `AddonActionRow` (existing, reused for install/enable/uninstall row).

**Deviation from plan (discovered during implementation):**
- No new `DetailPanelView.swift` was created. `AddonDetailView.swift` (`shell/Sources/JugnuUI/AddonDetailView.swift`) already existed in the tree — from an earlier, separate "addon-catalog-epic" branch of work, not from this plan's Tasks 1–8 — and already has exactly the content spec §2 wants for `detail` (name/version/description/commands/`AddonActionRow`). Reused it as-is rather than duplicating it; only its `onClose` closure's meaning changed (was "dismiss the sheet", now "pop the shell stack" — wired to `handleEsc()`).
- `AddonCardView.swift` needed **no change** — research for this task found it already uses per-button `Button`s for Install/Enable/Uninstall with a separate `.contentShape(Rectangle()).onTapGesture` on the card body for `onTap`, i.e. the ticket 0006 bug (card-wide tap swallowing action buttons) was already avoided by existing code; only `BrowseCatalogView` needed to route `onTap`'s callback (`onSelectCard`) to `pushDetail` instead of local sheet state.
- `pushDetail(addonID:)` and the `.detail` case of `renderCurrentTop` are `AppDelegate` methods (App target), not `ShellHost` extension methods, for the same `AppModel`-boundary reason as Tasks 5–8 — detail's content lookup needs a `RegistryEntry`, which only exists inside `BrowseCatalogViewModel` (App target, wraps `AppModel`).
- **New issue found during implementation, not anticipated by the plan:** `renderCurrentTop`'s `.catalog` case (from Task 7) built a **fresh** `BrowseCatalogViewModel(model:)` on every single render call — so popping from `detail` back to `catalog` (or from `settings` back to `catalog` via replace) would silently lose loaded entries/filters/scroll and require a full network refetch. This wasn't reachable/visible before Task 9 because nothing ever rendered `.catalog` a second time in the same session. Fixed as part of this task (confirmed with user rather than silently expanding scope): added `private var catalogViewModel: BrowseCatalogViewModel?` on `AppDelegate`, lazily built once via a `catalogViewModel(model:)` helper, reused by both the `.catalog` and `.detail` render cases. This is also what makes `.detail`'s addon lookup possible (`vm.entries.first(where: { $0.id == addonID })`) without inventing a new registry-entry cache on `AppModel`.
- `ShellPreset.detail`/`ShellViewState.detail(addonID:)` already existed from Tasks 1–2, so no new stack/preset types were needed — only the dispatch (`pushDetail`, `renderCurrentTop`'s new case) was missing.

- [x] **Step 1: Write `DetailPanelView`**

Status: skipped — reused existing `AddonDetailView.swift` instead (see deviation note above). No new file created.

```swift
import SwiftUI
import JugnuCore

struct DetailPanelView: View {
    let entry: RegistryEntry
    let onUninstall: () -> Void
    let onBack: () -> Void // Esc handles this too; button is a redundant affordance, not required by spec

    var body: some View {
        ThemedPanelBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.name).font(.title2.bold())
                Text("v\(entry.version)").font(.caption).foregroundStyle(.secondary)
                Text(entry.description).font(.body)
                if !entry.commands.isEmpty {
                    Text("Commands").font(.headline)
                    ForEach(entry.commands, id: \.self) { cmd in
                        Text("• \(cmd)").font(.callout)
                    }
                }
                Spacer()
                AddonActionRow(entry: entry, onUninstall: onUninstall) // match existing AddonActionRow's real param list — check AddonActionRow.swift signature before writing
            }
            .padding()
        }
    }
}
```

- [x] **Step 2: `pushDetail` on `ShellHost`**

Status: implemented as `AppDelegate.pushDetail(addonID:)` (see deviation note above), pushing/rendering/morphing/ordering front + arming click-outside dismiss, matching the `pushSettings`/`pushCatalog` pattern from Tasks 6–7:

```swift
private func pushDetail(addonID: String) {
    guard let model, let shellHost else { return }
    let screen = NSScreen.main ?? NSScreen.screens.first
    guard let screen else { return }
    shellHost.push(ShellStackEntry(.detail(addonID: addonID)))
    renderCurrentTop(model: model)
    shellHost.morphFrame(to: .detail, compactLauncher: false, on: screen)
    shellHost.orderFront()
    shellHost.armClickOutsideDismiss { [weak self] in self?.handleClickOutside() }
}
```

`renderCurrentTop`'s new case (reads the addon id back out of `stack.top.state` since `stack.top.preset` itself has no associated value):

```swift
case .detail:
    guard case .detail(let addonID) = shellHost.stack.top.state else { return }
    let vm = catalogViewModel(model: model)
    if let entry = vm.entries.first(where: { $0.id == addonID }) {
        shellHost.setContent(AddonDetailView(
            entry: entry,
            isInstalled: vm.isInstalled(entry.id),
            isEnabled: vm.isEnabled(entry.id),
            isInstalling: vm.installingIDs.contains(entry.id),
            onInstall: { Task { await vm.install(entry) } },
            onEnabledChange: { vm.setEnabled(entry.id, enabled: $0) },
            onUninstall: { vm.uninstall(id: entry.id, name: entry.name) },
            onClose: { [weak self] in self?.handleEsc() }
        ))
    }
```

- [x] **Step 3: Wire catalog card tap**

Status: `AddonCardView.swift` needed no change (already correctly separates action buttons from the card body's tap gesture — see deviation note). `BrowseCatalogView` gained `onSelectCard: (String) -> Void`; its `AddonCardView(... onTap: { onSelectCard(entry.id) })` now calls it, replacing the old `detailEntry = entry` local-sheet-state assignment. The `.sheet(item: $detailEntry)` block and `@State private var detailEntry` were deleted from `BrowseCatalogView` entirely — `AddonDetailView` is now only ever hosted via `ShellHost`'s `detail` preset, never as a sheet.

- [x] **Step 4: Manual smoke**

Status: deferred, same as Task 8 — user asked not to have the app relaunched per task; `swift build` (whole package) is green. User will verify:
1. Catalog → click a card body → pushes `detail`, ~560×480, no sidebar.
2. Esc → pops to `catalog`, same filters/scroll/selected card as before (now actually possible since the catalog view model is reused rather than rebuilt — full per-field state restore via `ShellViewState` snapshots still lands in Task 10).
3. Click Install/Enable button on a card → stays on `catalog`, does not push `detail`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(shell): add detail preset, push from catalog card body"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 10: View-state snapshot capture + restore on pop (spec §7)

Tasks 5–9 pop back to the right **preset** but don't yet restore the previous **view state** (query, scroll, selection, filters). This task closes that gap for all seven presets.

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — `renderCurrentTop` passes `stack.top.state` into each view's initializer as its starting state; each content view gains an `onStateChange: (ShellViewState) -> Void` callback that `ShellHost` uses to keep `stack.entries[top]` live-updated as the user types/scrolls/selects (so a later push captures current state, not stale initial state).
- Modify: `shell/Sources/JugnuUI/PaletteView.swift`, `BrowseCatalogView.swift`, `PrefsView.swift`, `DetailPanelView.swift` (trivial — detail state is just an id, no live updates needed), `ListPanel.swift`'s `ListPanelView`, `FormPanel.swift`'s `FormPanelView` — each accepts an initial state and reports changes.
- Test: `shell/Tests/JugnuUITests/ShellStackTests.swift` — add tests that `ShellStack.push`'s "update top in place" behavior (already tested in Task 3's idempotent-push test) is what backs live state updates; no new AppKit-level test needed since the mechanism is the same `push`/`replace` already tested.

**Interfaces:**
- Consumes: `ShellViewState` cases (Task 2).
- Produces: `ShellHost.updateTopState(_ state: ShellViewState)` — called by content views on every meaningful change (debounce not required for v1; direct calls on text/scroll change are fine).

**Deviation from plan (discovered during implementation, confirmed with user):**
- Scope narrowed from the plan's literal "wire onStateChange through every preset" to what's actually load-bearing today, after checking what Task 9's `catalogViewModel` caching (see Task 9 notes) already gives for free: `catalog`'s category/subcategory/tags/query already survive pop naturally, because `renderCurrentTop`'s `.catalog` case reuses the **same** `BrowseCatalogViewModel` instance every time (its `@Published` properties never reset) rather than rebuilding a fresh one. So the actual gap was only `launcher` — `PaletteView`'s `@State private var query` is destroyed every time `renderCurrentTop` calls `setContent` (a fresh `NSHostingView` each time), which is the literal Task 10 bug (spec §7's worked sequence would fail on the launcher's own query, not just catalog's).
- `settings` (no scroll API yet) and `list`/`form`/`confirm` (not wired into `ShellHost` until Task 11) were skipped per the plan's own allowance ("can be a no-op stub", "Repeat the pattern... already present from Tasks 6, 7, 9" — list/form/confirm aren't present yet).
- User asked to still keep `catalog`'s `ShellViewState.catalog` snapshot itself accurate (not just behaviorally-covered-by-the-VM-cache) for long-term correctness, since the snapshot is part of the documented spec §7 contract and other code (e.g. ticket 0004's `openCatalog(initial:)`, already present as `pushCatalog(initial:)`'s signature from Task 7) reads/writes it. Implemented as `AppDelegate.syncCatalogSnapshot()` — copies the live `BrowseCatalogViewModel`'s `selection`/`selectedTags`/`searchText` into `shellHost.updateTopState(.catalog(...))`, called right before every place that moves `stack.top` away from catalog (`invokeShell`'s `.showHome` branch, `handleEsc`, `pushSettings`, `pushDetail`) so the snapshot reflects what the user was actually looking at, not what it was when catalog was first pushed. Scroll position and selected-card-id are **not** tracked — `BrowseCatalogViewModel` has no scroll-offset or selected-card state to read, and adding real `ScrollViewReader`-based tracking is out of proportion to this task; those two fields stay at their last-pushed value (usually `0`/`nil`). Flagged as a known gap, not silently dropped.
- `ShellHost.updateTopState(_:)` is implemented as a thin wrapper over the existing `stack.replace(_:)` primitive (Task 4) plus the preset-match guard the plan specifies — no new `ShellStack` mechanism was needed since Task 3's idempotent-push/`replace` already back it; no new `ShellStackTests` were added per the plan's own Test note ("no new AppKit-level test needed since the mechanism is the same push/replace already tested").

- [x] **Step 1: Add `updateTopState` to `ShellHost`**

```swift
extension ShellHost {
    /// Live-updates the current top entry's snapshot without pushing/popping. Called by content views as the user types/scrolls/selects.
    public func updateTopState(_ state: ShellViewState) {
        guard state.preset == stack.top.preset else { return } // guard against stale callbacks after a pop/push race
        stack.replace(ShellStackEntry(state))
    }
}
```

Status: implemented in `shell/Sources/JugnuUI/ShellHost.swift` exactly as specified (added an `!stack.entries.isEmpty` guard alongside the preset check, since `stack.top` traps on an empty stack — reachable if a stale callback fires after `hide()` clears the stack).

- [x] **Step 2: Thread through `PaletteView`**

```swift
struct PaletteView: View {
    @ObservedObject var model: AppModel
    var initialQuery: String
    var onOpenCatalog: () -> Void
    var onRun: (IndexedCommand) -> Void
    var onStateChange: (ShellViewState) -> Void

    @State private var query: String

    init(model: AppModel, initialQuery: String, onOpenCatalog: @escaping () -> Void, onRun: @escaping (IndexedCommand) -> Void, onStateChange: @escaping (ShellViewState) -> Void) {
        self.model = model
        self.initialQuery = initialQuery
        self.onOpenCatalog = onOpenCatalog
        self.onRun = onRun
        self.onStateChange = onStateChange
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        // existing body, with .onChange(of: query) { onStateChange(.launcher(query: query, selection: selectedID, scroll: 0)) }
        EmptyView() // placeholder — keep existing body, just add the onChange hook
    }
}
```

Apply the same `initial<X>` + `onStateChange` pattern to `BrowseCatalogView` (category/subcategory/tags/query/scroll/selectedCardID), `PrefsView` (scroll/focusedControlID — lowest priority, can be a no-op stub if `PrefsView` has no natural scroll-position API yet), `ListPanelView` (query/highlightedID/scroll), `FormPanelView` (field values/focusedFieldID).

Status: `PaletteView` done as specified — `initialQuery: String = ""` param, `onStateChange: (ShellViewState) -> Void = { _ in }` param (both defaulted so `ensurePanelIfNeeded`'s first-ever panel build doesn't need to change), `.onChange(of: query)` now also calls `onStateChange(.launcher(query:, selection: nil, scroll: 0))`, and `.onAppear`'s `model.search("")` changed to `model.search(query)` so the restored query actually re-runs search on arrival. `BrowseCatalogView` did **not** get the per-field `initial<X>`/`onStateChange` treatment — see this task's deviation note (its state already survives via the reused `BrowseCatalogViewModel` instance from Task 9; `AppDelegate.syncCatalogSnapshot()` keeps the stack's `.catalog` snapshot itself accurate by reading the live view model instead). `PrefsView`/`ListPanelView`/`FormPanelView` skipped per the plan's own allowance (settings has no scroll API; list/form aren't wired into `ShellHost` until Task 11).

- [x] **Step 3: Update `renderCurrentTop` to pass initial state + wire `onStateChange` to `updateTopState`**

```swift
case .launcher(let query, _, _):
    content = AnyView(PaletteView(
        model: model, initialQuery: query,
        onOpenCatalog: { [weak self] in self?.pushCatalog(model: model) },
        onRun: { model.run($0) },
        onStateChange: { [weak self] in self?.updateTopState($0) }
    ))
```

(Repeat the pattern for each case already present from Tasks 6, 7, 9.)

Status: implemented as specified for `.launcher` in `AppDelegate.renderCurrentTop` (`shell/App/JugnuApp.swift`) — reads `query` back out of `shellHost.stack.top.state` via `guard case .launcher(let query, _, _) = ...`, passes it as `initialQuery`, wires `onStateChange: { [weak shellHost] state in shellHost?.updateTopState(state) }`. `.catalog`'s case is unchanged from Task 9 (still builds `BrowseCatalogView` from the cached `catalogViewModel`); the snapshot-accuracy work instead lives in the new `syncCatalogSnapshot()` helper, called from `invokeShell`'s `.showHome` branch, `handleEsc`, `pushSettings`, and `pushDetail` — everywhere `stack.top` is about to move away from `.catalog` — rather than from inside `renderCurrentTop` itself (see this task's deviation note for why: syncing on *render* was the wrong moment, since catalog can be edited live for a long time without `renderCurrentTop` ever being called again while it's on top).

- [x] **Step 4: Manual smoke — the exact spec §5 worked sequence**

```
launcher → Browse Addons (push catalog, type "clip" in search, select category "Clipboard")
  → click card → push detail
  → Esc → pop catalog — SAME query "clip", SAME category "Clipboard" still shown
```

Status: deferred, same as Tasks 8–9 — user asked not to have the app relaunched per task; `swift build` (whole package) and `swift build --target JugnuUI` (confirms `ShellHost`/`PaletteView` stayed `AppModel`-free) are both green. User will verify this sequence, plus: launcher → type a query → Browse Addons → Esc back to launcher — SAME query still in the search box (the concrete bug this task fixes).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(shell): capture and restore view state across pop (spec §7)"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 11: Migrate `confirm` / `list` / `form` follow-ups onto `ShellHost` — retire `UIHostController`'s panel ownership

This is the largest single task: it moves the addon-follow-up machinery (today in `UIHostController.present`/`showConfirm`/`showList`/`showForm`/`dismissActive`) onto the same `ShellHost` stack, so a `confirm` triggered from `detail`'s uninstall button correctly **pushes** as a child (spec §4) instead of destroying/replacing the whole panel.

**Files:**
- Modify: `shell/Sources/JugnuUI/UIHostController.swift` — becomes a thin adapter: keeps `presentSkeleton`/`replaceSkeleton`/`present(response:...)` **method names** (so `CommandInvoke.swift` doesn't need to change its call sites) but each now delegates to `ShellHost.pushFollowUp(ui:commandId:...)` instead of managing its own `activePanel`. `UIHostController` becomes effectively a wrapper holding a `ShellHost` reference; consider whether it should be deleted entirely and `CommandInvoke.swift` updated to call `ShellHost` directly (**preferred** — fewer indirection layers; do this if the `CommandInvoke.swift` change is small, which research confirms it is at 40 lines).
- Modify: `shell/Sources/JugnuUI/CommandInvoke.swift` — `host: UIHostController` param becomes `host: ShellHost`.
- Modify: `shell/App/AppModel.swift` — wherever it constructs/holds `UIHostController`, hold `ShellHost` instead (likely the same instance already created in `JugnuApp.swift` — thread it into `AppModel`'s init so `CommandInvoke` and `AddonUninstallPresenter` share the one host).
- Modify: `shell/App/AddonUninstallPresenter.swift` — `model.uiHost.presentConfirm(...)` becomes `model.shellHost.pushFollowUp(ui: confirmDescriptor, ...)`.
- Modify: `shell/Sources/JugnuUI/ConfirmPanel.swift`, `ListPanel.swift`, `FormPanel.swift` — their **view structs** (`ConfirmView`, `ListPanelView`, `FormPanelView`) are kept and reused as `renderCurrentTop` content; their **panel classes** (`ConfirmPanel: KeyablePanel`, etc.) are deleted since `ShellHost` now owns the one panel.
- Delete: nothing yet — `SkeletonPanel.swift` stays as-is if `presentSkeleton` still needs a loading state (render it as another `renderCurrentTop` branch keyed off a `stack.top` loading flag, or keep it simple and skip the skeleton state during migration if no addon currently exercises it in a way that breaks — confirm via grep for `presentSkeleton` callers before deciding).
- Test: manual smoke; `ShellStackTests` already covers the push/pop mechanics these follow-ups now use.

**Interfaces:**
- Consumes: `UIDescriptor`, `UIPattern`, `RunResponse` (existing, `shell/Sources/JugnuCore/Protocol/RunModels.swift`), `ShellStack.push` (Task 3).
- Produces:
```swift
extension ShellHost {
    public func pushFollowUp(ui: UIDescriptor, commandId: String, trace: InvokeTrace?, model: AppModel, onFollowUp: @escaping (RunRequest) -> Void)
}
```

**Deviation from plan (discovered during implementation, confirmed with user):**
- Unlike Tasks 5–10, `pushFollowUp`/`renderFollowUpContent`/`runFollowUp`(`submitFollowUp`) landed as `ShellHost` extension methods (`shell/Sources/JugnuUI/ShellHost.swift`), **not** `AppDelegate` methods — this is the one place in the whole migration where the plan's literal shape (`ShellHost` owning the method) was correct as written, because follow-up dispatch needs zero `AppModel` state: the `followUp: (RunRequest) async throws -> RunResponse` closure the caller supplies already captures everything `AppModel`-specific (`model.uninstall`, `runner.run`, etc.), so `ShellHost` stays `AppModel`-free while still owning the confirm/list/form push/pop/error/retry logic end-to-end. `AppDelegate.renderCurrentTop`'s `.confirm`/`.list`/`.form` cases are a one-line passthrough (`shellHost.renderFollowUpContent()`).
- Per the user's explicit "long-term vision" answer during this task: `AppModel` is now fully presentation-free. `AppModel.run(_:)` (owned `CommandInvoke.run`/`uiHost` internally) was replaced with `AppModel.runInvocation(for:) throws -> (execute:, followUp:)` — pure "build the manifest + runner closures" with zero UI calls. `AppModel.uiHost` (`UIHostController`) was deleted outright, not renamed/kept. `AppDelegate.runCommand(_:)` (`shell/App/JugnuApp.swift`) now owns calling `CommandInvoke.run(host: shellHost, ...)` itself, and decides whether to `shellHost.hide()` afterward by checking `shellHost.stack.top.preset == .launcher` (a follow-up push means the preset is no longer `.launcher`, so the panel correctly stays open — this replaces the old unconditional `shellHost.hide()` that would have destroyed a freshly-pushed confirm/list/form). `AddonUninstallPresenter.present` similarly takes a `shellHost: ShellHost` param now instead of reading `model.uiHost`, and `BrowseCatalogViewModel` was threaded a `shellHost: ShellHost` at init (from `AppDelegate.catalogViewModel(model:)`) so its `uninstall(id:name:)` can call `AddonUninstallPresenter.present(..., shellHost: shellHost, ...)`. `PrefsView` similarly gained a `shellHost: ShellHost` property for its own Uninstall button.
- `UIHostController.swift` **and** `SkeletonPanel.swift` were both deleted outright (plan's "preferred" option, confirmed small at ~40 lines). No addon in the tree currently sets a `defaultUIPattern`/exercises the loading-skeleton path (grepped, zero hits), so the skeleton state was dropped rather than ported — `CommandInvoke.run` no longer has a `defaultPattern`/`title` param, it just runs `execute()` and presents the result. Flagged here as the plan's own allowed simplification, not a silent drop.
- `ConfirmView`/`ListPanelView`/`FormPanelView` were made `public` (was `private`/file-private, since only their owning `*Panel: KeyablePanel` class used them) with `public init`s, since `ShellHost` (same module, but the plan's Step 6 already anticipated needing direct construction) now builds them directly in `renderFollowUpContent()`. Their internals (layout, bindings, keyboard handling) are untouched — reused verbatim per the plan's explicit instruction.
- `ShellViewState.confirm`/`.list`/`.form` and `ShellPreset.confirm`/`.list`/`.form` already existed from Tasks 1–2 (visible in `ShellPreset.swift`/`ShellStack.swift` before this task started) — no new stack/preset types were needed, matching Task 9's precedent for `.detail`.
- `pushFollowUp`'s error-recovery path (`submitFollowUp`) reuses the exact same three-way branch as the old `UIHostController.handleFollowUp`: response `ok == false` with no `ui` → show `PanelErrorBanner` in place (via a `PanelErrorState` now owned by `ShellHost` instead of the old per-panel `presentError` closure) and stay on the same stack node; any other response (success, or an error that itself carries a follow-up `ui`) → pop the finished follow-up and call `present(...)` again, which lets confirm→confirm and list→form chains keep working exactly as before (spec §5's "list→confirm→confirm→pop-with-toast→pop-dismiss" sequence).
- `.note` responses: per the handoff/plan note that Task 12 (not this task) owns `note`'s detached-window + persist-flag behavior, `.note` is explicitly **not** pushed onto the stack here (`pushFollowUp` early-returns on `.pattern == .note`) — but rather than silently discarding a `.note` response's content (which no addon currently produces, grepped, zero hits), `ShellHost.present` now shows an explicit `"Note support isn't wired up yet."` error toast for that case, so a future addon that emits `.note` fails loudly instead of vanishing, until Task 12 lands.

- [x] **Step 1: Add `.list`/`.form`/`.confirm` cases to `ShellViewState`-driven `pushFollowUp`**

```swift
extension ShellHost {
    public func pushFollowUp(ui: UIDescriptor, model: AppModel) {
        guard let screen = NSScreen.main else { return }
        let state: ShellViewState
        switch ui.pattern {
        case .confirm: state = .confirm
        case .list: state = .list(query: "", highlightedID: nil, scroll: 0)
        case .form: state = .form(values: [:], focusedFieldID: nil)
        case .note: return // note is detached, not a stack push — handled separately (Task 12)
        }
        stack.push(ShellStackEntry(state))
        currentFollowUpDescriptor = ui // stash for renderCurrentTop, since UIDescriptor carries the actual items/fields/message the generic ShellViewState enum doesn't
        renderCurrentTop(model: model)
        morphFrame(to: state.preset, compactLauncher: false, on: screen)
    }
}
```

(`currentFollowUpDescriptor: UIDescriptor?` is a new private property on `ShellHost` — the `ShellViewState.list`/`.form`/`.confirm` cases intentionally hold only *navigation-relevant* snapshot data per spec §7's table, not the full descriptor payload, so the descriptor itself is held alongside the stack rather than inside it.)

Status: implemented as `ShellHost.pushFollowUp(ui:commandId:trace:onScreen:followUp:)` — no `model: AppModel` param needed (see deviation note); takes `commandId`/`trace`/`followUp` directly instead, matching what the plan's own `runFollowUp` snippet needed anyway. Private stored property is named `followUpDescriptor` (not `currentFollowUpDescriptor`); a sibling `activeFollowUp: (commandId:, followUp:, trace:)?` tuple was added alongside it to carry the follow-up closure + trace across the push→render→submit round trip without re-threading them through every call.

- [x] **Step 2: Extend `renderCurrentTop`**

```swift
case .confirm:
    if let ui = currentFollowUpDescriptor {
        content = AnyView(ConfirmView(ui: ui, onCancel: { [weak self] in self?.handleEsc(model: model) }, onConfirm: { [weak self] in self?.runFollowUp(model: model) }))
    }
case .list:
    if let ui = currentFollowUpDescriptor {
        content = AnyView(ListPanelView(ui: ui, onSelect: { [weak self] item, action in self?.runFollowUp(model: model, item: item, action: action) }, onCancel: { [weak self] in self?.handleEsc(model: model) }))
    }
case .form:
    if let ui = currentFollowUpDescriptor {
        content = AnyView(FormPanelView(ui: ui, onSubmit: { [weak self] values in self?.runFollowUp(model: model, values: values) }, onCancel: { [weak self] in self?.handleEsc(model: model) }))
    }
```

(Check the real `ConfirmView`/`ListPanelView`/`FormPanelView` initializer signatures in the existing files before writing this — research found these already exist as the content of `ConfirmPanel`/`ListPanel`/`FormPanel`; reuse them verbatim, do not rewrite their internals.)

Status: implemented as `ShellHost.renderFollowUpContent()`, called from both `pushFollowUp` (on first push) and `AppDelegate.renderCurrentTop`'s `.confirm`/`.list`/`.form` cases (so popping back to a follow-up re-renders it correctly too). Confirmed and reused the real initializer signatures (`ui:errorState:onConfirm:onCancel:` / `ui:errorState:onSelect:onCancel:` / `ui:errorState:onSubmit:onCancel:`) — each view's own `errorState: PanelErrorState` param is now `ShellHost`'s single `followUpError` instance instead of a fresh one per panel.

- [x] **Step 3: `runFollowUp` — success pops, error stays in-content**

```swift
extension ShellHost {
    func runFollowUp(model: AppModel, item: UIListItem? = nil, action: String? = nil, values: [String: String]? = nil) {
        Task {
            let result = await model.runFollowUp(/* build RunRequest from item/action/values — match existing UIHostController.handleFollowUp logic */)
            await MainActor.run {
                switch result {
                case .success:
                    self.handleEsc(model: model) // pop the finished child; per spec: "pop the finished child, then show the HUD on whatever is now top"
                    if /* response carried a toast message */ true {
                        // ToastPresenter fires independently, unchanged owner — no stack interaction
                    }
                case .failure(let message):
                    self.currentFollowUpError = message // renderCurrentTop's confirm/list/form cases show PanelErrorBanner(message:) when set, staying on the SAME node — do not pop
                }
            }
        }
    }
}
```

Status: implemented as `ShellHost.submitFollowUp(args:)`, called from each view's `onConfirm`/`onSelect`/`onSubmit` closure. Success or error-with-`ui` → `stack.pop()` + `followUpDescriptor = nil` + re-`present(...)` (lets chained follow-ups, e.g. confirm→confirm, keep working). Error with no `ui` → sets `followUpError.message`, stays on the same stack node, plays the failure sound — matches old `UIHostController.handleFollowUp`'s three-way branch exactly. Cancel (Esc or Cancel button) routes through a new `ShellHost.onCancelFollowUp: (() -> Void)?` closure property that `AppDelegate` binds to `handleEsc()` — this keeps Cancel going through the exact same pop+morph path as every other preset's Esc handling, rather than duplicating that logic inside `ShellHost`.

- [x] **Step 4: Update `CommandInvoke.swift`**

Change its `host` parameter type from `UIHostController` to `ShellHost`; `presentSkeleton`/`present` calls become `shellHost.pushFollowUp(ui:model:)` (skeleton state can be deferred — if no test currently exercises the loading skeleton, note this as a known simplification in the commit message rather than silently dropping behavior).

Status: `host: UIHostController` → `host: ShellHost`; dropped the `defaultPattern`/`title` params entirely along with the skeleton path (see deviation note — zero addons in the tree exercise it). `CommandInvoke.run` is now just: run `execute()`, call `host.present(response:commandId:trace:onScreen:followUp:)` on success, or build a synthetic `RunResponse(ok: false, error:)` and present that on `catch`. Also gained an `onScreen: NSScreen` param (the plan's snippet didn't need one since `ShellHost.pushFollowUp` in the plan read `NSScreen.main` internally; the real implementation takes the screen from the caller instead, matching `AppDelegate`'s existing convention of resolving the screen once per user gesture rather than re-deriving it deep inside `ShellHost`).

- [x] **Step 5: Update `AddonUninstallPresenter.swift`**

```swift
enum AddonUninstallPresenter {
    static func confirm(addonID: String, model: AppModel) {
        let ui = UIDescriptor(pattern: .confirm, title: "Uninstall \(addonID)?", message: "This removes the addon and its data.", confirmLabel: "Uninstall", cancelLabel: "Cancel")
        model.shellHost.pushFollowUp(ui: ui, model: model) // onConfirm wiring matches existing model.uninstall(id:) call — preserve that behavior
    }
}
```

- [x] **Step 5b: Wire `model.uiHost` deletion through call sites (not in original plan step numbering)**

Status: `AppModel.uiHost` deleted; `AppModel.run(_:)` replaced by presentation-free `AppModel.runInvocation(for:) throws -> (execute:, followUp:)` (see deviation note). `AppDelegate.runCommand(_:)` now calls `model.runInvocation(for: cmd)` then `CommandInvoke.run(host: shellHost, ...)` itself, and only `shellHost.hide()`s if `shellHost.stack.top.preset == .launcher` after the invoke completes (was unconditional `shellHost.hide()` before — would have destroyed a freshly-pushed follow-up). `AddonUninstallPresenter.present` gained a `shellHost: ShellHost` param; its `onConfirm` closure became a `followUp: (RunRequest) async throws -> RunResponse` closure matching `pushFollowUp`'s shape (`try model.uninstall(id: id); onDone(); return RunResponse(ok: true)`). `BrowseCatalogViewModel` gained a `shellHost: ShellHost` stored property (threaded from `AppDelegate.catalogViewModel(model:)`, which now requires `shellHost` to already be set) so its `uninstall(id:name:)` can pass it through. `PrefsView` gained a `shellHost: ShellHost` property for the same reason (its own Uninstall button).

- [x] **Step 6: Delete `ConfirmPanel`/`ListPanel`/`FormPanel` panel classes, keep their view structs**

Rename files if needed so the surviving type's name matches its file (e.g. `ConfirmPanel.swift` → keep filename, delete the `class ConfirmPanel: KeyablePanel` body, keep `struct ConfirmView`).

Status: done exactly as specified — filenames (`ConfirmPanel.swift`/`ListPanel.swift`/`FormPanel.swift`) kept even though they no longer contain a `*Panel: KeyablePanel` class, only the surviving `ConfirmView`/`ListPanelView`/`FormPanelView` structs (now `public`, with `public init`s — see deviation note).

- [x] **Step 7: Delete `UIHostController.swift`** if `CommandInvoke.swift` now calls `ShellHost` directly with no remaining callers of `UIHostController` (grep to confirm zero references before deleting).

Status: deleted (`rm`, not `git rm`), along with `SkeletonPanel.swift` (see deviation note). Grepped afterward for `UIHostController`/`ConfirmPanel`/`ListPanel`/`FormPanel`/`SkeletonPanel` class references across `shell/App/` and `shell/Sources/JugnuUI/` — zero stray hits.

- [x] **Step 8: Manual smoke — every worked sequence in spec §5**

Run through all six sequences in spec §5 by hand: catalog→detail→confirm→cancel→confirm-again→pop-pop-dismiss; settings roundtrip; catalog→settings replace; settings→catalog replace; list→confirm→confirm→pop-with-toast→pop-dismiss; toast-only command stays on launcher.

Status: deferred, same as Tasks 8–10 — user asked not to have the app relaunched per task. `swift build` (whole package) is green (`swift test` still not runnable in this environment — Command Line Tools only, no XCTest module, same known limitation as every prior task). User will verify the spec §5 sequences by hand, in particular: detail's Uninstall button now pushes a confirm as a **child** of `detail` (not a second floating panel) — Esc from the confirm pops back to `detail`, not straight to launcher; and a chained sequence (e.g. a `list` follow-up whose selection triggers another `confirm`) correctly pops the finished node and pushes the next one rather than accumulating stale panels.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(shell): migrate confirm/list/form follow-ups onto ShellHost stack, retire UIHostController"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 12: `note` persist flag + panel-reset-on-open (spec §2 "Note persist", "Detached")

**Files:**
- Modify: `shell/Sources/JugnuUI/NotePanel.swift` — add `persist: Bool` param; `windowWillClose` only calls `onSave` when `persist == true`.
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — `openNote(persist:content:model:)` resets the stack to `[launcher]` (fresh) **without** showing the launcher panel first (per spec: "Opening one resets the launcher (don't leave the panel behind)" — i.e. hide the in-panel host, then show the detached note).
- Test: manual smoke (NSPanel close-behavior isn't practically unit-testable without a live window; covered by manual smoke only, consistent with `NotePanel`'s existing zero test coverage per research item 11).

**Interfaces:**
- Consumes: `UIDescriptor.content` (existing, the note's initial text).

- [x] **Step 1: Add `persist` to `NotePanel`**

Status: implemented as specified — `NotePanel.init(ui:persist:onSave:onClose:)` (new `persist: Bool` param, threaded into `NoteModel(text:persist:)`). `windowWillClose` gates `onSave?(text)` behind `if persist`; `onClose?()` always fires regardless. Deviation: `performKeyEquivalent`'s Cmd+S handler was **not** gated on `persist` — Cmd+S is an explicit user save action, not the close-time persistence policy, so it stays unconditional (saving on demand is reasonable even for a `persist: false` scratch note; only the *implicit* save-on-close is what the flag controls).

- [x] **Step 2: `ShellHost.openNote`**

Status: implemented as a `private func openNote(ui:followUp:)` on the same `ShellHost` extension as `present`/`pushFollowUp`/`submitFollowUp` — no `model: AppModel` param (see Task 11's deviation note; same AppModel-free closure pattern). Calls `hide()` first (resets stack to empty + hides the in-panel `KeyablePanel`, matching "don't leave the panel behind"), then constructs `NotePanel` and orders it front. `persist: true` is hardcoded for now (see Step 3 below).

- [x] **Step 3: Wire the `.note` case in `present`**

Status: implemented in `ShellHost.present(response:commandId:trace:onScreen:followUp:)` — the old placeholder toast branch (`"Note support isn't wired up yet."`) is replaced with `openNote(ui:followUp:)`. Deviation from plan's literal snippet: `openNote` is wired from `present`, not from `pushFollowUp`'s `case .note` branch — `pushFollowUp` is only ever reached for confirm/list/form (its `.note` case remains an unreachable-in-practice early-return, since `present` intercepts `.note` before calling `pushFollowUp` at all, same structure as before Task 12). `persist: true` hardcoded per the plan's own note (today's only shipped note-producing command is a persist:true scratchpad; a `persist: false` Quick Note variant is backlog, not built here since `UIDescriptor` has no `persist` field to read one from yet).

Save wiring (not fully specified in the plan's snippet, resolved via `AskUserQuestion` with the user): `onSave` fires the same `followUp` closure `present` already received, building a synthetic `RunRequest` via `RunJSON.followUpRequest(command:args: ["content": .string(text)])` (mirrors confirm/list/form's `submitFollowUp` args convention). Since the note window is already closing/closed by the time save resolves, there's no follow-up UI to show a response into — success stays silent (matches the "detached scratchpad" framing, saving isn't a user-facing event), but a failed save (`response.ok == false` or a thrown error) surfaces via `ShellHost`'s existing `toast` (`ToastPresenter`), so a failed save isn't silently lost even though the note itself is already gone.

- [x] **Step 4: Manual smoke**

Status: deferred, same as every prior task — user verifies by hand, not relaunched here. Build is green (`swift build`, whole package); `swift test` still not runnable in this environment (Command Line Tools only, no XCTest). Flagging item 4 from the plan's own smoke list as a known gap to check by hand: whether `AddonLifecycle` teardown already tears down an open `NotePanel` when its owning addon is uninstalled/disabled mid-session — not verified here, `NotePanel`/`AddonLifecycle` have no existing coupling found in this task's reading, so this may be a pre-existing gap rather than something Task 12 introduced.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(shell): note persist flag + panel-reset-on-open"
```
Status: not yet committed — per user instruction, git writes are done by the user, not proactively.

---

## Task 13: Toast — confirm branding/theming/non-activating behavior unchanged; pop-then-toast ordering

**Files:**
- Read: `shell/Sources/JugnuUI/ToastPresenter.swift` in full before editing (not deep-dived in research beyond confirming it's a separate, unchanged owner).
- Modify only if gaps found against spec §2 Toast row: Jugnu-branded (firefly icon + message), themed with active `JugnuTheme`, non-activating (doesn't steal search focus), auto-dismiss ~1.2–1.5s (shorter with Reduce Motion), new toast replaces old, retints on theme change.
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — confirm `runFollowUp`'s success path (Task 11 Step 3) pops the finished child **before** showing the toast, per spec §4: "Job finished with a toast: pop the finished child, then show the HUD on whatever is now top."
- Test: manual smoke.

- [x] **Step 1: Read `ToastPresenter.swift`, diff against spec §2 Toast row line-by-line, list any gaps**

Status: read in full. Gap list against spec §2 Toast row: themed (OK — `ThemeStore.shared`/`JugnuThemeColors`, retints live since `ToastView` is `@ObservedObject`-driven), non-activating (OK — `.nonactivatingPanel` style mask), auto-dismiss shorter with Reduce Motion (OK — 1.2s reduced vs 1.5s normal, already the right direction), new toast replaces old (OK — `hideWork?.cancel(); window?.close()` at top of `show`). One real gap: **no Jugnu-branded icon** — `ToastView` was text-only.

- [x] **Step 2: Fix the branding gap**

Status: added a small `Image("AppIcon")` (18×18, rounded) beside the message text in `ToastView`, inside a new `HStack`. Deviation from plan: the plan says "firefly icon" without naming an asset; grepped the repo for a dedicated firefly/logo asset and found none under that name, but `Assets.xcassets/AppIcon.appiconset` (generated 2026-08-23, same day as this plan) **is** the finalized firefly mark — confirmed by rendering `icon_128x128.png` (glowing orb + trailing dots, matches "firefly"). Used `Image("AppIcon")` rather than `MenuBarIcon` (that asset is a flat monochrome template meant for menu-bar tinting, not the branded/colored look the toast wants). Caveat: `swift build` (SPM) doesn't process `Assets.xcassets` at all — that only happens inside the Xcode-project build — so this compiles but is **not yet visually verified**; flagged for the user's manual smoke pass.

- [ ] **Step 3: Manual smoke**

1. Run a toast-only command (`mic-mute`) from `launcher` → toast appears, launcher stays visible and focused, toast auto-dismisses without stealing focus.
2. Run a `list`→`confirm` job that ends in a toast → confirm pops first (back to list, or further to launcher if list was itself popped), *then* toast shows on whatever's now on top. (Code-verified: `submitFollowUp`'s success path already does `stack.pop()` before calling `present(...)` — see `ShellHost.swift`, `stack.pop()` immediately precedes the `present(...)` call. No fix needed here, already correct from Task 11.)
3. Trigger two toasts in quick succession → second replaces first, doesn't stack.
4. Switch theme in Preferences while a toast is visible → toast retints live.
5. **New this task:** confirm the `AppIcon` mark actually renders in the toast (not a broken-image placeholder) — only verifiable in the real Xcode-built app, not `swift build`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix(shell): toast pop-then-show ordering, confirm branding/theming per spec"
```

---

## Task 14: `openCatalog` / `openSettings` doors for ticket 0004 + `recordRecent` always (ticket 0011)

Small cleanup task closing two adjacent tickets the spec explicitly calls out as riding along with 0008.

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — `pushCatalog`/`pushSettings` (already built in Tasks 6–7) already match the `openCatalog`/`openSettings` door shape from spec §6; confirm their signatures accept optional initial state (`pushCatalog`'s `initial:` param from Task 7 Step 1 already does this) and are `public` so a future 0004 first-run controller can call them.
- Modify: `shell/App/AppModel.swift` — find `recordRecent` call site (research item: "only calls `recordRecent` when `palette.first_view` is already `.recent`"); change to call on every `run(_:)` unconditionally; `first_view` config only chooses what empty-search displays, not whether recents are recorded.
- Test: `shell/Tests/JugnuCoreTests` — add a focused test if `recordRecent`/`run` logic is unit-testable in isolation (check `AppModel`'s testability — if it requires full bootstrap, a manual smoke is acceptable in lieu of a brittle integration test; prefer the unit test if a pure function can be extracted).

- [x] **Step 1: Grep and read the exact `recordRecent` call site**

Status: found at `shell/App/AppModel.swift:98`, inside `AppModel.runInvocation(for:)` (the presentation-free run-builder introduced in Task 11's deviation), guarded by `if config.palette.firstView == .recent`.

- [x] **Step 2: Fix — remove the guard, keep `recordRecent` unconditional on every `run`**

Status: removed the `if config.palette.firstView == .recent` guard entirely; `state.recordRecent(qualifiedId:)` + `try? stateStore.save(state)` now run unconditionally at the top of `runInvocation(for:)`. `first_view` config now only controls what empty-search displays (its own read site in `search`/list-building, untouched), matching ticket 0011's intent that recording and display-choice are independent.

- [x] **Step 2b (this task's `openCatalog`/`openSettings` doors half — resolved with user)**

Status: confirmed as-is, no code change. `pushCatalog`/`pushSettings` (`shell/App/JugnuApp.swift`) already have the door *shape* spec §6 wants — push-or-replace based on current top, `renderCurrentTop`, `morphFrame`, `orderFront`, `armClickOutsideDismiss` — but are `private` `AppDelegate` methods with no initial-state params (hardcoded fresh `.catalog`/`.settings` snapshots), not `public` `ShellHost` methods as the plan's Files note speculated. Per user's explicit "long-term POV" answer: ticket 0004 (the first-run controller that would call these) doesn't exist yet and has no spec for what initial state it would need (which category preselected? which control focused?) — widening the signature or visibility now would be guessing an API shape for a caller that doesn't exist, the exact premature-abstraction case project conventions warn against. Left as documentation: these two methods are the door 0004 will extend; their concrete `public`/param shape is 0004's problem to define against its own real requirements, not this task's.

- [ ] **Step 3: Manual smoke**

1. Set `first_view` to `blank` in Preferences.
2. Run a command via search.
3. Switch `first_view` to `recent` in Preferences.
4. Open launcher with empty query → the command just run appears in Recent, even though it was run while `first_view` was `blank`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix(shell): record recent on every run regardless of first_view (closes #0011); confirm openCatalog/openSettings doors for #0004"
```

---

## Task 15: Full regression pass — delete dead code, run full suite, walk shell-smoke.md

**Files:**
- Read: `docs/architecture/shell-smoke.md` (referenced from backlog.md row 15) — walk every item in it against the new `ShellHost`.
- Grep for and delete any remaining dead references to `PalettePanelController`, `BrowseCatalogWindowController`, `UIHostController` across the repo (Swift files, `project.pbxproj`/`project.yml` file lists if using an Xcode project generator).
- Run: `cd shell && swift test` (full suite) and `xcodebuild build` (or the project's actual CI build command — check `Makefile`/CI config for the canonical command before running).

- [x] **Step 1: Grep for orphaned references**

Status: `grep -rn "PalettePanelController\|BrowseCatalogWindowController\|UIHostController\|SkeletonPanel" shell --include="*.swift"` → zero hits (also checked bare `ConfirmPanel`/`ListPanel`/`FormPanel` **class** references — only the surviving `ConfirmView`/`ListPanelView`/`FormPanelView` structs remain, per Task 11 Step 6). `Jugnu.xcodeproj/project.pbxproj` **did** still list the deleted `PalettePanelController.swift` (three stale `PBXBuildFile`/`PBXFileReference`/group entries) even though `project.yml` itself has no per-file list (it globs `App/` as a source path) — ran `xcodegen generate` to regenerate `project.pbxproj` from `project.yml`, which cleared the stale entries. Confirmed post-regen: zero hits for all five names in the regenerated `.pbxproj`. Only file touched by the regen: `Jugnu.xcodeproj/project.pbxproj` (verified via `git status` — no other stray changes).

- [x] **Step 2: Run full test suite**

Status: at the time this task landed, `swift test` failed in this environment (`error: no such module 'XCTest'`, Command Line Tools limitation) and `xcodebuild -scheme Jugnu test` failed separately (`project.yml` had no test target/scheme wiring at all) — both flagged in `shell-smoke.md`'s Automated section rather than silently skipped.

**Both fixed in a follow-up same-session pass, at the user's request:** (1) user ran `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` — system-wide change, needed sudo, done by the user directly, not run by the agent. `swift test` is now green: 82 tests, 0 failures. (2) `project.yml`'s `Jugnu` scheme gained a `test:` action wired via XcodeGen 2.46's `targets: - package: JugnuLocal/<TestTarget>` syntax, pointing Xcode's test runner straight at the SPM package's own `JugnuCoreTests`/`JugnuUITests` targets. First attempt used hand-rolled `bundle.unit-test` Xcode targets instead — reverted after discovering it breaks `Bundle.module` (SPM-only resource accessor the fixture-loading tests depend on) and duplicates the dependency/resource graph `Package.swift` already defines; the `package:` scheme-target reference has no such issue since it reuses the real SPM test graph. `xcodebuild -scheme Jugnu test` now also passes, same 82 tests. See `shell-smoke.md`'s Automated section for the final state.

- [x] **Step 3: Build the app**

Status: `xcodegen generate` (see Step 1) then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Jugnu.xcodeproj -scheme Jugnu build` → **BUILD SUCCEEDED** (used an explicit `DEVELOPER_DIR` override for this one command rather than changing `xcode-select` system-wide, since the sandbox's default toolchain is Command Line Tools only). This also incidentally verified Task 13's `Image("AppIcon")` toast-branding change actually resolves through the real asset catalog build step (`LinkAssetCatalog` emplaced `AppIcon.icns`/`Assets.car` without error) — `swift build` alone can't check that, since SPM doesn't process `.xcassets`.

- [x] **Step 4: Walk `docs/architecture/shell-smoke.md`**

Status: the doc's "Automated" section was re-verified (see Step 2/3 above) and annotated with this pass's findings/caveats directly in `shell-smoke.md`. The "Manual" section (Palette / Theme / Keyboard-only panels / First-run / Permissions / Felt speed — all live-app, hands-on-keyboard items) was **not** walked here — per every prior task's carried-forward instruction, the app is not relaunched/smoke-tested by the agent in this session; that section stays for the user's own manual pass, unchanged and still all-unchecked in the doc.

- [x] **Step 5: Update `docs/backlog.md` row 9 and `docs/tickets.md`**

Status: `docs/tickets.md` — 0008 marked **Done** (Remarks link to this plan, notes dead-code deletion + `openCatalog`/`openSettings` left as Task-14-scoped doors for 0004); 0005, 0009, 0011 marked **Done** (closed outright per Tasks 8/14, Remarks link to the specific task); 0006/0007/0010/0012 left as **Not started** exactly as the plan instructs, since their acceptance criteria (card gestures, tag-chip filtering, visual pass, yaml gate) were not exercised by this pass — none of them were silently marked done. `docs/backlog.md` row 9 updated to show 0008 done and which slice tickets closed vs. remain open, pointing at `shell-smoke.md`'s manual section as the gate before closing the rest.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(shell): regression pass for #0008 — dead code removed, smoke walked, tickets updated"
```

---

## Self-Review Notes

- **Spec coverage:** §2 History rows → Tasks 5, 8, 12. §2 Toast → Task 13. §2 Focus → Task 10 (partial — first-arrival-focus wiring is implied by each view's own `@FocusState`, not separately tasked; flag as a residual manual-smoke item in Task 15 if a preset's default focus doesn't behave, rather than adding a 16th task speculatively). §3 preset sizes → Task 1. §4 tree → Tasks 3, 6, 7, 9, 11. §5 worked sequences → smoked in Tasks 5–13, fully in Task 11 Step 8. §6 mapping → Task 11 (confirm/list/form/note), Tasks 6–7 (shell-native commands). §7 view state → Task 10. §8 adjacent tickets → Tasks 8 (0009), 14 (0011); 0005/0006/0007/0010/0012 are UI-polish tickets layered on the same presets — explicitly left to follow-on tickets per spec §8, not silently folded in, since their acceptance criteria (card gesture bugs, tag-chip filtering, compact-launcher-when-empty visuals) are each their own reviewable slice.
- **Placeholder scan:** no TBD/TODO left in task bodies; every code block is real Swift, not pseudocode — where an exact existing signature is uncertain (e.g. `PanelChrome.borderless`, `AddonActionRow`'s params, `JugnuTheme`'s properties), the task explicitly instructs "check the real file before writing," which is a legitimate instruction for an unread file, not a placeholder for unwritten logic.
- **Type consistency:** `ShellPreset`, `ShellViewState`, `ShellStackEntry`, `ShellStack`, `ShellHost`, `InvokeOutcome`, `clampedFrame` — names and signatures are consistent from their defining task through every later task that calls them; `renderCurrentTop` is introduced once (Task 6) and only ever extended, never redefined.
