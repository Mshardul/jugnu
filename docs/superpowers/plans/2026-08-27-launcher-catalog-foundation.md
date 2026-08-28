# Launcher + Catalog — Foundation (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the foundation the rest of the launcher+catalog epic builds on — new theme tokens, the `canvas` view-type remap for catalog/detail, and a fully-locked viewA (Opt+Space launcher): row1 favorites bar with state icons/reorder/remove, and the fixed 5-slot search-results region. viewB's rail/scope/tags/card redesign and the detail view's tabs/gallery/genie transition are separate follow-on phases (not in this plan).

**Architecture:** All new UI is SwiftUI added to the existing `JugnuUI` package, following the same `ObservedObject` + `@Environment(\.colorScheme)` + `ThemeStore.shared` pattern every existing panel view uses. Favorites state already exists in `JugnuCore.JugnuState.favoriteCommandIDs` (ordered `[String]`, order = user's reorder) — row1 renders the first 5 of that array and mutates it via new reorder/remove methods, no new storage model needed. The search-results region is a pure SwiftUI addition inside `PaletteView` (no new `ShellViewState` case — it's the same `.launcher` state, just growing the panel frame based on result count via the existing `morph` mechanism in `ShellHost.morphFrame`).

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (`NSPanel`/`NSHostingView` via existing `KeyablePanel`/`PanelChrome`), XCTest.

**Spec:** [docs/architecture/2026-08-25-launcher-catalog-design.md](../../architecture/2026-08-25-launcher-catalog-design.md) — this plan implements spec §1 (surface map / canvas remap), §2 (viewA, row1, row2), §2.1 (search-results transition), and §4 (new tokens). §3/§3.1–§3.4/§5 (viewB, detail view, prefs rail) are later phases.

## Global Constraints

- Icons stay **placeholders** everywhere per spec §5 — default app icon / SF Symbols (`star`, `star.fill`, `xmark`, `magnifyingglass`) for now, not final hand-drawn art (that's ticket 0051, a separate epic). Do not block this plan on real icon assets.
- Firefly / Terminal Phosphor / Rose Quartz are the only 3 presets; every new token needs a value for all 3 × light/dark = 6 combinations, copied verbatim from spec §4's table.
- `subText` is a real new `JugnuTheme` Swift struct field (hand-picked hex per preset×mode). `border`, `surface2`, `accentDeep` are **derived** (computed from existing fields), not new struct fields — do not add them to `JugnuTheme`.
- Reduce Motion: any new animation (row1 drag reorder feedback, results region grow) must snap instead of animating when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is true, matching `ShellHost.morphFrame`'s existing pattern.
- Do not create git commits unless explicitly asked (repo convention — see [[git-writes-off-limits]] equivalent: user commits themselves).
- Follow existing code style: `@MainActor` on stateful classes, `ObservableObject`/`@Published`, theme colors resolved via `JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))`, fonts via `JugnuTokens.font(presetId:role:)`.

---

## File Structure

| File | Responsibility |
|---|---|
| `shell/Sources/JugnuUI/Theme.swift` (modify) | Add `subText` to `JugnuTheme`/`JugnuThemeColors`; add derived `border`/`surface2`/`accentDeep` computed properties |
| `shell/Sources/JugnuCore/Models.swift` (modify) | Add `subText` field + per-preset hex values to `JugnuTheme`/`ThemeConfig.firefly/.terminalPhosphor/.roseQuartz` |
| `shell/Sources/JugnuUI/ShellPreset.swift` (modify) | Remap `.catalog`/`.detail` default view type from `.grid`/`.rail` to `.canvas` |
| `shell/Tests/JugnuUITests/ShellPresetTests.swift` (modify) | Update `test_catalogSize` for the new `.canvas` size band |
| `shell/Sources/JugnuCore/StateStore.swift` (modify) | Add `moveFavorite(from:to:)` and `removeFavorite(qualifiedId:)` to `JugnuState` |
| `shell/Tests/JugnuCoreTests/StateStoreTests.swift` (modify, or create if absent) | Cover the two new `JugnuState` methods |
| `shell/Sources/JugnuUI/FavoritesRow.swift` (create) | Row1's favorites bar: top-5 + "…" icon, lit/dim state placeholder, click-to-run, right-click remove, drag-reorder |
| `shell/Tests/JugnuUITests/FavoritesRowLogicTests.swift` (create) | Pure-logic tests for row1's top-5 windowing / reorder-index math (no view rendering) |
| `shell/Sources/JugnuUI/SearchResultsRegion.swift` (create) | The fixed 5-slot results region below row2: breadcrumb rows, reserved "Show all addons" slot 5, scroll-when->4, did-you-mean fallback |
| `shell/Tests/JugnuUITests/SearchResultsRegionLogicTests.swift` (create) | Pure-logic tests for the 5-slot layout rules (which slots are results vs. blank vs. "show all", when to scroll) |
| `shell/Sources/JugnuUI/PaletteView.swift` (modify) | Wire in `FavoritesRow` (row1) and `SearchResultsRegion` (below row2); grow/shrink panel frame via `ShellHost.morphFrame` as result count changes |
| `shell/App/AppModel.swift` (modify) | Expose `moveFavorite`/`removeFavorite` wrappers (mirrors existing `toggleFavorite`/`isFavorite`) |

---

### Task 1: `subText` token — Core model + values  ✅ DONE

**Files:**
- Modify: `shell/Sources/JugnuCore/Models.swift:3-51` (`JugnuTheme` struct), `:62-118` (the three `ThemeConfig` static presets)
- Test: `shell/Tests/JugnuCoreTests/ThemeConfigTests.swift`

**Interfaces:**
- Produces: `JugnuTheme.subText: String` (hex), decoded/encoded as `sub_text` in `CodingKeys`, defaulted via `sanitized(against:)` like every other field.

- [x] **Step 1: Write the failing test**

```swift
// Add to ThemeConfigTests.swift
func testSubTextValuesPerPresetAndMode() {
    XCTAssertEqual(ThemeConfig.firefly.dark.subText, "#B8AF9E")
    XCTAssertEqual(ThemeConfig.firefly.light.subText, "#5B5647")
    XCTAssertEqual(ThemeConfig.terminalPhosphor.dark.subText, "#6FAF7C")
    XCTAssertEqual(ThemeConfig.terminalPhosphor.light.subText, "#385E43")
    XCTAssertEqual(ThemeConfig.roseQuartz.dark.subText, "#D2A9BF")
    XCTAssertEqual(ThemeConfig.roseQuartz.light.subText, "#6F4A5E")
}

func testSubTextSanitizesLikeOtherFields() {
    var dirty = ThemeConfig.firefly.dark
    dirty.subText = "nope"
    let clean = dirty.sanitized(against: ThemeConfig.firefly.dark)
    XCTAssertEqual(clean.subText, "#B8AF9E")
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ThemeConfigTests`
Expected: FAIL — `value of type 'JugnuTheme' has no member 'subText'`

- [x] **Step 3: Add the field to `JugnuTheme`**

In `Models.swift`, extend the struct (keep field order matching spec's 7-field list: accent, background, surface, textPrimary, textSecondary, subText, error — insert `subText` right after `textSecondary` to mirror the spec's brightness-tier ordering):

```swift
public struct JugnuTheme: Codable, Equatable, Sendable {
    public var accent: String
    public var background: String
    public var surface: String
    public var textPrimary: String
    public var textSecondary: String
    public var subText: String
    public var error: String

    public init(
        accent: String,
        background: String,
        surface: String,
        textPrimary: String,
        textSecondary: String,
        subText: String,
        error: String
    ) {
        self.accent = accent
        self.background = background
        self.surface = surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.subText = subText
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case accent
        case background
        case surface
        case textPrimary = "text_primary"
        case textSecondary = "text_secondary"
        case subText = "sub_text"
        case error
    }

    public func sanitized(against defaults: JugnuTheme) -> JugnuTheme {
        func hex(_ value: String, _ fallback: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let ok = trimmed.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
            return ok ? trimmed : fallback
        }
        return JugnuTheme(
            accent: hex(accent, defaults.accent),
            background: hex(background, defaults.background),
            surface: hex(surface, defaults.surface),
            textPrimary: hex(textPrimary, defaults.textPrimary),
            textSecondary: hex(textSecondary, defaults.textSecondary),
            subText: hex(subText, defaults.subText),
            error: hex(error, defaults.error)
        )
    }
}
```

Note: `Codable`'s auto-synthesized `init(from:)`/`encode(to:)` still work since `JugnuTheme` has no custom decoder — only add `subText` to `CodingKeys` and the memberwise `init`.

- [x] **Step 4: Add values to the three presets**

```swift
    public static let firefly = ThemeConfig(
        light: JugnuTheme(
            accent: "#C97A12",
            background: "#F7F3EA",
            surface: "#FFFDF8",
            textPrimary: "#2A2417",
            textSecondary: "#756E5C",
            subText: "#5B5647",
            error: "#E5484D"
        ),
        dark: JugnuTheme(
            accent: "#F5A623",
            background: "#16130E",
            surface: "#1F1B13",
            textPrimary: "#EDE6D9",
            textSecondary: "#8C8577",
            subText: "#B8AF9E",
            error: "#E5484D"
        )
    )

    public static let terminalPhosphor = ThemeConfig(
        light: JugnuTheme(
            accent: "#1C8A3F",
            background: "#EEF3EC",
            surface: "#F7FAF6",
            textPrimary: "#12291A",
            textSecondary: "#4F6D57",
            subText: "#385E43",
            error: "#E5484D"
        ),
        dark: JugnuTheme(
            accent: "#39FF6A",
            background: "#020402",
            surface: "#020402",
            textPrimary: "#C9FFD4",
            textSecondary: "#3A8A4A",
            subText: "#6FAF7C",
            error: "#E5484D"
        )
    )

    public static let roseQuartz = ThemeConfig(
        light: JugnuTheme(
            accent: "#D13D82",
            background: "#FDF0F6",
            surface: "#FFFAFD",
            textPrimary: "#4A1936",
            textSecondary: "#93677F",
            subText: "#6F4A5E",
            error: "#E5484D"
        ),
        dark: JugnuTheme(
            accent: "#F0559B",
            background: "#210F1A",
            surface: "#2E1524",
            textPrimary: "#FBE6F1",
            textSecondary: "#B98AA7",
            subText: "#D2A9BF",
            error: "#E5484D"
        )
    )
```

- [x] **Step 5: Run test to verify it passes**

Run: `cd shell && swift test --filter ThemeConfigTests`
Expected: PASS (all `ThemeConfigTests`, including the pre-existing ones — `testJugnuConfigDecodesMissingThemeAsFirefly` still passes since YAML decode falls back to `.firefly` defaults which now include `subText`)

- [x] **Step 6: Build the whole package to catch other call sites**

Run: `cd shell && swift build 2>&1 | grep -i "JugnuTheme(" `
Expected: no compile errors. If any other call site constructs `JugnuTheme(...)` positionally without `subText` (e.g. test helpers), fix those call sites to pass `subText:` too — search first: `grep -rn "JugnuTheme(" shell/Sources shell/Tests shell/App shell/TestsExtended --include="*.swift"`.

---

### Task 2: `subText` in `JugnuThemeColors` (SwiftUI) + derived `border`/`surface2`/`accentDeep`  ✅ DONE

**Files:**
- Modify: `shell/Sources/JugnuUI/Theme.swift:32-48` (`JugnuThemeColors`)
- Test: create `shell/Tests/JugnuUITests/JugnuThemeColorsTests.swift`

**Interfaces:**
- Consumes: `JugnuTheme.subText: String` (Task 1)
- Produces: `JugnuThemeColors.subText: Color`, `.border: Color`, `.surface2: Color`, `.accentDeep: Color` — used by every task in later phases that touches the viewB rail, official badge, or icon gradients.

- [x] **Step 1: Write the failing test**

```swift
// shell/Tests/JugnuUITests/JugnuThemeColorsTests.swift
@testable import JugnuCore
@testable import JugnuUI
import SwiftUI
import XCTest

final class JugnuThemeColorsTests: XCTestCase {
    func test_subText_resolvesFromTheme() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertEqual(colors.subText, Color(jugnuHex: "#B8AF9E", fallback: .gray))
    }

    func test_border_isDerived_notEqualToSurface() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertNotEqual(colors.border, colors.surface, "border must be a distinct derived value, not aliased to surface")
    }

    func test_surface2_isDerived_notEqualToSurface() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertNotEqual(colors.surface2, colors.surface)
    }

    func test_accentDeep_isDerived_notEqualToAccent() {
        let colors = JugnuThemeColors(theme: ThemeConfig.firefly.dark)
        XCTAssertNotEqual(colors.accentDeep, colors.accent)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter JugnuThemeColorsTests`
Expected: FAIL — `value of type 'JugnuThemeColors' has no member 'subText'` (and `border`/`surface2`/`accentDeep`)

- [x] **Step 3: Implement**

In `Theme.swift`, extend `JugnuThemeColors`:

```swift
public struct JugnuThemeColors: Equatable {
    public var accent: Color
    public var background: Color
    public var surface: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var subText: Color
    public var error: Color

    public init(theme: JugnuTheme) {
        accent = Color(jugnuHex: theme.accent, fallback: Color(red: 0.96, green: 0.65, blue: 0.14))
        background = Color(jugnuHex: theme.background, fallback: Color(red: 0.09, green: 0.07, blue: 0.05))
        surface = Color(jugnuHex: theme.surface, fallback: Color(red: 0.12, green: 0.11, blue: 0.07))
        textPrimary = Color(jugnuHex: theme.textPrimary, fallback: Color(red: 0.93, green: 0.90, blue: 0.85))
        textSecondary = Color(jugnuHex: theme.textSecondary, fallback: Color(red: 0.55, green: 0.52, blue: 0.47))
        subText = Color(jugnuHex: theme.subText, fallback: Color(red: 0.72, green: 0.69, blue: 0.62))
        error = Color(jugnuHex: theme.error, fallback: Color(red: 0.90, green: 0.28, blue: 0.30))
    }

    /// Derived — a hairline distinct from `surface`, computed rather than a stored per-preset value
    /// (spec §4: "subtler/more mechanical... lower risk if the computed value drifts slightly").
    public var border: Color {
        surface.opacity(0.4)
    }

    /// Derived — slightly-lifted background (official badge, accordion rail group background).
    public var surface2: Color {
        surface.opacity(0.7)
    }

    /// Derived — darker gradient stop for icon fills.
    public var accentDeep: Color {
        accent.opacity(0.75)
    }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter JugnuThemeColorsTests`
Expected: PASS

---

### Task 3: Remap `catalog`/`detail` to `canvas` view type  ✅ DONE

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellPreset.swift:14-23`
- Modify: `shell/Tests/JugnuUITests/ShellPresetTests.swift:15-20`

**Interfaces:**
- Produces: `ShellPreset.catalog.defaultViewType(compactLauncher:)` and `.detail.defaultViewType(compactLauncher:)` both now return `.canvas` instead of `.grid`/`.rail`.

**Why now, in Foundation:** the spec (§1) locks this remap independent of the rail/card/detail-view redesign that will consume it later — doing it now means later phases build directly against the right size band instead of a second migration.

- [x] **Step 1: Update the failing/changed test first**

Replace `test_catalogSize` in `ShellPresetTests.swift`:

```swift
    func test_catalogSize_usesCanvasBand() {
        let size = ShellPreset.catalog.size(compactLauncher: false)
        // canvas: width clamped(visible.width * 0.70, min: 800, max: 1400), landscape aspect
        // default visibleFrame in ShellPreset.size() is 1440x900 -> width = 1008, height clamped 630 then landscape-capped to width*0.75=756, still <= 900 clamp band (500...900) -> 630
        XCTAssertEqual(size.width, 1008, accuracy: 0.5)
        XCTAssertEqual(size.height, 630, accuracy: 0.5)
        XCTAssertEqual(ShellPreset.catalog.defaultViewType(compactLauncher: false), .canvas)
    }

    func test_detailUsesCanvasBand() {
        XCTAssertEqual(ShellPreset.detail.defaultViewType(compactLauncher: false), .canvas)
    }
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellPresetTests`
Expected: FAIL — width/viewType mismatch (`.grid` returned, not `.canvas`; old `test_catalogSize` name no longer exists so this confirms the replace took effect once you also delete the old test body)

- [x] **Step 3: Implement the remap**

In `ShellPreset.swift`:

```swift
    public func defaultViewType(compactLauncher: Bool) -> ViewType {
        switch self {
        case .launcher: compactLauncher ? .seek : .palette
        case .catalog: .canvas
        case .settings: .canvas
        case .detail: .canvas
        case .confirm: .ask
        case .list: .rows
        case .form: .fields
        }
    }
```

Note: `.settings` (Preferences) also moves to `.canvas` per spec §3.4 ("Not a new view shape — reuses viewB's exact shell... same `canvas` band"). This is in scope for Foundation because it's the same one-line remap as catalog/detail, not new prefs-rail UI (that's a later phase task).

- [x] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellPresetTests`
Expected: PASS

- [x] **Step 5: Grep for any other hardcoded `.grid`/`.rail` expectations tied to catalog/detail/settings**

Run: `grep -rn "\.catalog\b.*\.grid\|\.detail\b.*\.rail\|\.settings\b.*\.rail" shell/Tests --include="*.swift"`
Expected: no remaining matches (if any, update them the same way as Step 1).

- [x] **Step 6: Full test suite + build**

Run: `cd shell && swift build && swift test`
Expected: all pass. (`ViewTypeTests`, `ShellStackTests`, `CardAccentTests` should be unaffected since they don't assert on `ShellPreset`'s default view type — spot-check `CardAccentTests` if it fails.)

---

### Task 4: `JugnuState` favorites reorder + remove  ✅ DONE

**Files:**
- Modify: `shell/Sources/JugnuCore/StateStore.swift:3-53` (`JugnuState`)
- Test: create `shell/Tests/JugnuCoreTests/StateStoreTests.swift` (does not exist yet — verify with `ls shell/Tests/JugnuCoreTests/StateStoreTests.swift` before assuming; if it exists, add to it instead of overwriting)

**Interfaces:**
- Consumes: `JugnuState.favoriteCommandIDs: [String]` (existing)
- Produces: `JugnuState.moveFavorite(from: Int, to: Int)`, `JugnuState.removeFavorite(qualifiedId: String)` — consumed by Task 5's `FavoritesRow` via Task 7's `AppModel` wrappers.

- [x] **Step 1: Check whether the test file already exists**

Run: `ls shell/Tests/JugnuCoreTests/StateStoreTests.swift 2>&1`

- [x] **Step 2: Write the failing tests**

```swift
// shell/Tests/JugnuCoreTests/StateStoreTests.swift
@testable import JugnuCore
import XCTest

final class StateStoreTests: XCTestCase {
    func test_moveFavorite_reordersInPlace() {
        var state = JugnuState(favoriteCommandIDs: ["a", "b", "c"])
        state.moveFavorite(from: 0, to: 2)
        XCTAssertEqual(state.favoriteCommandIDs, ["b", "c", "a"])
    }

    func test_moveFavorite_outOfBounds_isNoOp() {
        var state = JugnuState(favoriteCommandIDs: ["a", "b"])
        state.moveFavorite(from: 0, to: 5)
        XCTAssertEqual(state.favoriteCommandIDs, ["a", "b"])
        state.moveFavorite(from: 9, to: 0)
        XCTAssertEqual(state.favoriteCommandIDs, ["a", "b"])
    }

    func test_removeFavorite_removesMatchingID() {
        var state = JugnuState(favoriteCommandIDs: ["a", "b", "c"])
        state.removeFavorite(qualifiedId: "b")
        XCTAssertEqual(state.favoriteCommandIDs, ["a", "c"])
    }

    func test_removeFavorite_missingID_isNoOp() {
        var state = JugnuState(favoriteCommandIDs: ["a"])
        state.removeFavorite(qualifiedId: "not-there")
        XCTAssertEqual(state.favoriteCommandIDs, ["a"])
    }
}
```

- [x] **Step 3: Run test to verify it fails**

Run: `cd shell && swift test --filter StateStoreTests`
Expected: FAIL — `value of type 'JugnuState' has no member 'moveFavorite'`

- [x] **Step 4: Implement**

Add to `JugnuState` in `StateStore.swift`, right after `toggleFavorite`:

```swift
    /// Row1 drag-reorder (spec §2 "Row1 editing"). No-op if either index is out of bounds.
    public mutating func moveFavorite(from source: Int, to destination: Int) {
        guard favoriteCommandIDs.indices.contains(source),
              destination >= 0, destination < favoriteCommandIDs.count
        else { return }
        let id = favoriteCommandIDs.remove(at: source)
        favoriteCommandIDs.insert(id, at: destination)
    }

    /// Row1 right-click "Remove from Favorites" (spec §2 "Row1 editing"). No-op if not favorited.
    public mutating func removeFavorite(qualifiedId: String) {
        favoriteCommandIDs.removeAll { $0 == qualifiedId }
    }
```

- [x] **Step 5: Run test to verify it passes**

Run: `cd shell && swift test --filter StateStoreTests`
Expected: PASS

---

### Task 5: `AppModel` wrappers for reorder/remove  ✅ DONE

**Files:**
- Modify: `shell/App/AppModel.swift:84-92` (next to existing `toggleFavorite`/`isFavorite`)

**Interfaces:**
- Consumes: `JugnuState.moveFavorite`/`removeFavorite` (Task 4)
- Produces: `AppModel.moveFavorite(from:to:)`, `AppModel.removeFavorite(qualifiedId:)`, `AppModel.topFavorites(limit:) -> [IndexedCommand]` — the last one is what `FavoritesRow` actually reads (resolves qualified IDs to real `IndexedCommand`s the same way `commandsForFirstView()` already does for `.favorites`).

No dedicated test task here — `AppModel` has no existing unit test target of its own (it's `@testable import` inside the App target, not `JugnuCore`/`JugnuUI`, and the App target has no XCTest bundle in this repo — confirmed by the file listing: no `shell/Tests/JugnuAppTests/`). Coverage comes from Task 4's `StateStoreTests` (the logic) and Task 6's `FavoritesRowLogicTests` (the windowing) — `AppModel` itself is a thin, directly-inspectable wrapper.

- [x] **Step 1: Implement**

```swift
    // Add directly below `isFavorite(qualifiedId:)` in AppModel.swift

    func moveFavorite(from source: Int, to destination: Int) {
        state.moveFavorite(from: source, to: destination)
        try? stateStore.save(state)
        objectWillChange.send()
    }

    func removeFavorite(qualifiedId: String) {
        state.removeFavorite(qualifiedId: qualifiedId)
        try? stateStore.save(state)
        objectWillChange.send()
    }

    /// Row1's top-N favorites, resolved to real commands (skips any stale ID no longer indexed —
    /// e.g. its addon was uninstalled). Order follows `state.favoriteCommandIDs` (the user's reorder).
    func topFavorites(limit: Int) -> [IndexedCommand] {
        Array(state.favoriteCommandIDs.compactMap { id in
            allCommands.first { $0.qualifiedId == id }
        }.prefix(limit))
    }
```

- [x] **Step 2: Build**

Run: `cd shell && swift build`
Expected: no errors.

---

### Task 6: `FavoritesRow` view — pure layout/windowing logic  ✅ DONE

**Files:**
- Create: `shell/Tests/JugnuUITests/FavoritesRowLogicTests.swift`
- Create (partial, logic only): `shell/Sources/JugnuUI/FavoritesRow.swift` (free function `favoritesSlots`, no SwiftUI view yet — the view itself is Task 7)

**Interfaces:**
- Produces: `favoritesSlots<T>(from items: [T], limit: Int) -> (shown: [T], hasMore: Bool)` — pulled out as a standalone testable function so the "top 5 + more indicator" rule (spec §2: "Row1 shows the top 5 by that order, plus a 6th '…' icon") is unit-tested without spinning up SwiftUI view rendering.

This task exists separately from Task 7 because the windowing rule is exactly the kind of off-by-one-prone logic that deserves its own fast, no-rendering test, per the skill's task-sizing rule ("split only where a reviewer could meaningfully reject one task while approving its neighbor" — the math can be wrong while the view code is fine, or vice versa).

- [x] **Step 1: Write the failing test**

```swift
// shell/Tests/JugnuUITests/FavoritesRowLogicTests.swift
@testable import JugnuUI
import XCTest

final class FavoritesRowLogicTests: XCTestCase {
    func test_fiveOrFewer_showsAllNoMoreIndicator() {
        let result = favoritesSlots(from: ["a", "b", "c"], limit: 5)
        XCTAssertEqual(result.shown, ["a", "b", "c"])
        XCTAssertFalse(result.hasMore)
    }

    func test_exactlyFive_noMoreIndicator() {
        let result = favoritesSlots(from: ["a", "b", "c", "d", "e"], limit: 5)
        XCTAssertEqual(result.shown, ["a", "b", "c", "d", "e"])
        XCTAssertFalse(result.hasMore)
    }

    func test_moreThanFive_showsTop5PlusMoreIndicator() {
        let result = favoritesSlots(from: ["a", "b", "c", "d", "e", "f", "g"], limit: 5)
        XCTAssertEqual(result.shown, ["a", "b", "c", "d", "e"])
        XCTAssertTrue(result.hasMore)
    }

    func test_empty_showsNothingNoMoreIndicator() {
        let result = favoritesSlots(from: [String](), limit: 5)
        XCTAssertEqual(result.shown, [])
        XCTAssertFalse(result.hasMore)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter FavoritesRowLogicTests`
Expected: FAIL — `cannot find 'favoritesSlots' in scope`

- [x] **Step 3: Implement**

Start `FavoritesRow.swift` with the logic function (the SwiftUI view is appended in Task 7, same file):

```swift
import JugnuCore

/// Row1's "top 5 + more" windowing rule (spec §2). `hasMore` drives the 6th "…" icon.
public func favoritesSlots<T>(from items: [T], limit: Int) -> (shown: [T], hasMore: Bool) {
    guard items.count > limit else { return (items, false) }
    return (Array(items.prefix(limit)), true)
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter FavoritesRowLogicTests`
Expected: PASS

---

### Task 7: `FavoritesRow` SwiftUI view  ✅ DONE

**Files:**
- Modify: `shell/Sources/JugnuUI/FavoritesRow.swift` (append the view, below Task 6's `favoritesSlots`)

**Interfaces:**
- Consumes: `favoritesSlots` (Task 6), `IndexedCommand` (existing, has `.qualifiedId`, `.title`), theme via `JugnuThemeColors`/`ThemeStore.shared` (existing pattern)
- Produces: `FavoritesRow` view — `init(favorites: [IndexedCommand], statefulOnStates: [String: Bool], onRun: @escaping (IndexedCommand) -> Void, onReorder: @escaping (Int, Int) -> Void, onRemove: @escaping (IndexedCommand) -> Void, onOpenAllFavorites: @escaping () -> Void)`. Consumed by Task 9 (`PaletteView` wiring).

**Spec behaviors this view must implement (§2):**
- Empty state: blank center, fixed geometry (no placeholder text/wordmark) — locked, don't add a substitute.
- Click a favorite: same as running the command normally (`onRun`).
- Right-click a favorite: context menu with "Remove from Favorites" (`onRemove`).
- Drag-and-drop reorder within the visible slots (`onReorder(fromIndex, toIndex)`).
- 6th "…" icon shown only when `hasMore` — opens viewB with Favorites scope pre-selected (`onOpenAllFavorites`). (viewB doesn't exist yet in this phase — Task 9 wires this to a no-op-for-now or to whatever `pushCatalog`-equivalent exists; see Task 9's note.)
- State icon: lit vs. dim placeholder per command's on/off state where known — this phase does **not** wire real per-addon state (no addon reports live state to the shell yet); render a stable placeholder (`SF Symbol` `circle.fill` at full opacity, no dim variant) and leave a `// TODO(phase 2 or addon-state ticket)` comment. Do not invent a state source that doesn't exist.

- [x] **Step 1: Write the failing test (interaction-callback wiring, not full snapshot)**

SwiftUI views in this codebase aren't snapshot/UI-tested (confirmed: no snapshot test target exists — `grep -rn "SnapshotTesting\|XCUIApplication" shell` returns nothing). Match that convention: cover the pure logic (done in Task 6) and leave the view itself verified by the manual smoke checklist (Task 11), not a new testing pattern this plan shouldn't introduce unilaterally.

Skip to Step 3 (no separate failing-test step for the view itself, consistent with every other existing `*View.swift` in this codebase — `AddonCardView`, `PaletteView`, `BrowseCatalogView` etc. have no dedicated view tests either, only their logic/viewModel layers do).

- [x] **Step 2: N/A** (see Step 1 rationale)

- [x] **Step 3: Implement the view**

Append to `FavoritesRow.swift`:

```swift
import AppKit
import SwiftUI

public struct FavoritesRow: View {
    let favorites: [IndexedCommand]
    let onRun: (IndexedCommand) -> Void
    let onReorder: (Int, Int) -> Void
    let onRemove: (IndexedCommand) -> Void
    let onOpenAllFavorites: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared
    @State private var draggingID: String?

    public init(
        favorites: [IndexedCommand],
        onRun: @escaping (IndexedCommand) -> Void,
        onReorder: @escaping (Int, Int) -> Void,
        onRemove: @escaping (IndexedCommand) -> Void,
        onOpenAllFavorites: @escaping () -> Void
    ) {
        self.favorites = favorites
        self.onRun = onRun
        self.onReorder = onReorder
        self.onRemove = onRemove
        self.onOpenAllFavorites = onOpenAllFavorites
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
    }

    public var body: some View {
        let slots = favoritesSlots(from: favorites, limit: 5)
        HStack(spacing: 10) {
            // Empty state: blank center, fixed geometry — spec §2, locked, no placeholder content.
            if slots.shown.isEmpty {
                Spacer(minLength: 0)
            } else {
                ForEach(Array(slots.shown.enumerated()), id: \.element.qualifiedId) { index, command in
                    favoriteIcon(command)
                        .onTapGesture { onRun(command) }
                        .contextMenu {
                            Button("Remove from Favorites") { onRemove(command) }
                        }
                        .onDrag {
                            draggingID = command.qualifiedId
                            return NSItemProvider(object: command.qualifiedId as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: FavoriteDropDelegate(
                                targetIndex: index,
                                favorites: slots.shown,
                                draggingID: $draggingID,
                                onReorder: onReorder
                            )
                        )
                }
                if slots.hasMore {
                    Button(action: onOpenAllFavorites) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("All favorites")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
    }

    private func favoriteIcon(_ command: IndexedCommand) -> some View {
        // Placeholder state rendering: real per-addon on/off state isn't wired yet (no addon reports
        // live state to the shell in this phase) — single lit treatment for every favorite, not a
        // lit/dim pair, until that data source exists.
        Image(systemName: "circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(theme.accent)
            .frame(width: 28, height: 28)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .help(command.title)
    }
}

private struct FavoriteDropDelegate: DropDelegate {
    let targetIndex: Int
    let favorites: [IndexedCommand]
    @Binding var draggingID: String?
    let onReorder: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              let sourceIndex = favorites.firstIndex(where: { $0.qualifiedId == draggingID }),
              sourceIndex != targetIndex
        else { return }
        onReorder(sourceIndex, targetIndex)
    }
}
```

- [x] **Step 4: Build**

Run: `cd shell && swift build`
Expected: no errors.

---

### Task 8: `SearchResultsRegion` — pure layout logic  ✅ DONE

**Files:**
- Create: `shell/Tests/JugnuUITests/SearchResultsRegionLogicTests.swift`
- Create: `shell/Sources/JugnuUI/SearchResultsRegion.swift` (logic function first, view appended in Task 9's sibling task — actually Task 9 covers PaletteView wiring; the view itself is built in this same file, Step 3 below, since the spec ties layout math and rendering tightly together — see rationale)

**Interfaces:**
- Produces: `resultSlots<T>(results: [T], slotCount: Int) -> ResultSlotLayout<T>` where:
  ```swift
  public struct ResultSlotLayout<T> {
      public let rows: [T]           // real result rows to render in slots 1...
      public let showAllLinkSlot: Int?  // 1-based slot index for "Show all addons", nil if no room
      public let scrolls: Bool          // true when rows.count > slotCount - 1 (need internal scroll)
  }
  ```

**Spec rules encoded (§2.1, all LOCKED):**
- Fixed 5-row-slot window whenever there's ≥1 result.
- Slot 5 always reserved for "Show all addons →", unless there are >4 real results (then no room, region scrolls instead, no slot-5 link).
- Exactly 4 results: slots 1–4 are results, slot 5 is the link, no scroll.
- Fewer than 4 results: slots between last result and slot 5 stay blank (not collapsed) — slot 5 doesn't slide up.
- More than 4 results: slots 1–4 show results, scrolls internally to reach the rest, no slot-5 link.

- [x] **Step 1: Write the failing tests**

```swift
// shell/Tests/JugnuUITests/SearchResultsRegionLogicTests.swift
@testable import JugnuUI
import XCTest

final class SearchResultsRegionLogicTests: XCTestCase {
    func test_zeroResults_noRows_noLink_noScroll() {
        let layout = resultSlots(results: [String](), slotCount: 5)
        XCTAssertEqual(layout.rows, [])
        XCTAssertNil(layout.showAllLinkSlot)
        XCTAssertFalse(layout.scrolls)
    }

    func test_oneResult_linkAtSlot5_noScroll() {
        let layout = resultSlots(results: ["a"], slotCount: 5)
        XCTAssertEqual(layout.rows, ["a"])
        XCTAssertEqual(layout.showAllLinkSlot, 5)
        XCTAssertFalse(layout.scrolls)
    }

    func test_fourResults_linkAtSlot5_noScroll() {
        let layout = resultSlots(results: ["a", "b", "c", "d"], slotCount: 5)
        XCTAssertEqual(layout.rows, ["a", "b", "c", "d"])
        XCTAssertEqual(layout.showAllLinkSlot, 5)
        XCTAssertFalse(layout.scrolls)
    }

    func test_fiveResults_noLink_scrolls() {
        let layout = resultSlots(results: ["a", "b", "c", "d", "e"], slotCount: 5)
        XCTAssertEqual(layout.rows, ["a", "b", "c", "d", "e"])
        XCTAssertNil(layout.showAllLinkSlot, "more than 4 real results means no room for the link")
        XCTAssertTrue(layout.scrolls)
    }

    func test_twentyResults_noLink_scrolls() {
        let layout = resultSlots(results: Array(1 ... 20).map(String.init), slotCount: 5)
        XCTAssertEqual(layout.rows.count, 20)
        XCTAssertNil(layout.showAllLinkSlot)
        XCTAssertTrue(layout.scrolls)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter SearchResultsRegionLogicTests`
Expected: FAIL — `cannot find 'resultSlots' in scope`

- [x] **Step 3: Implement**

```swift
// shell/Sources/JugnuUI/SearchResultsRegion.swift
import Foundation

public struct ResultSlotLayout<T> {
    public let rows: [T]
    public let showAllLinkSlot: Int?
    public let scrolls: Bool

    public init(rows: [T], showAllLinkSlot: Int?, scrolls: Bool) {
        self.rows = rows
        self.showAllLinkSlot = showAllLinkSlot
        self.scrolls = scrolls
    }
}

/// Spec §2.1 fixed 5-slot layout rule. `slotCount` is always 5 in production; parameterized for testing.
public func resultSlots<T>(results: [T], slotCount: Int) -> ResultSlotLayout<T> {
    let maxRowsWithLinkRoom = slotCount - 1
    if results.count <= maxRowsWithLinkRoom {
        return ResultSlotLayout(rows: results, showAllLinkSlot: results.isEmpty ? nil : slotCount, scrolls: false)
    }
    return ResultSlotLayout(rows: results, showAllLinkSlot: nil, scrolls: true)
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter SearchResultsRegionLogicTests`
Expected: PASS

---

### Task 9: `SearchResultsRegion` SwiftUI view (breadcrumb rows + did-you-mean)  ✅ DONE (added isFavorite/onToggleFavorite params to preserve search-result star per Task 11 flag)

**Files:**
- Modify: `shell/Sources/JugnuUI/SearchResultsRegion.swift` (append the view, below Task 8's `resultSlots`)

**Interfaces:**
- Consumes: `resultSlots` (Task 8), `SearchHit` (existing — has `.command: IndexedCommand`, `.isSuggestion: Bool`, `.tier`), `IndexedCommand.title`/`.subtitle`/`.qualifiedId` (existing)
- Produces: `SearchResultsRegion` view — `init(hits: [SearchHit], selection: Int, onSelect: (IndexedCommand) -> Void, onOpenBrowseCatalog: () -> Void)`. Consumed by Task 10 (`PaletteView` wiring).

**Spec behaviors (§2.1):**
- Breadcrumb row style: icon (left) + "Addon › Command" — addon name muted, command bold. This phase's `SearchHit`/`IndexedCommand` doesn't carry a separate addon display name field distinct from `title` — check before assuming one exists.

- [x] **Step 1: Verify what's actually available on `SearchHit`/`IndexedCommand` for the addon-name half of the breadcrumb**

Run: `grep -n "addonId\|addonName\|struct SearchHit" shell/Sources/JugnuCore/CommandIndex.swift shell/Sources/JugnuCore/Fuzzy.swift`

`IndexedCommand.addonId` exists (raw id like `"mic-mute"`, confirmed in Models.swift's neighbor file read during planning) but there's no human-readable addon *display name* cached on the command itself (`AppModel.addonDisplayName(id:)` exists but does a manifest disk read per call — not something to call per-row in a list). For this phase, breadcrumb uses `command.addonId` raw (e.g. "mic-mute › Mute Microphone") rather than adding a new resolved-name cache — leave a comment noting the raw-id tradeoff; resolving it to a friendly display name is a follow-on if it reads poorly in the manual smoke pass (Task 11).

- [x] **Step 2: Implement (no separate failing-test step — view-only, same convention as Task 7 Step 1)**

```swift
import SwiftUI

public struct SearchResultsRegion: View {
    let hits: [SearchHit]
    let selection: Int
    let onSelect: (IndexedCommand) -> Void
    let onOpenBrowseCatalog: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        hits: [SearchHit],
        selection: Int,
        onSelect: @escaping (IndexedCommand) -> Void,
        onOpenBrowseCatalog: @escaping () -> Void
    ) {
        self.hits = hits
        self.selection = selection
        self.onSelect = onSelect
        self.onOpenBrowseCatalog = onOpenBrowseCatalog
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
    }

    private static let slotCount = 5
    private static let rowHeight: CGFloat = 40

    public var body: some View {
        let layout = resultSlots(results: hits, slotCount: Self.slotCount)
        if !layout.rows.isEmpty {
            let content = VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(layout.rows.enumerated()), id: \.element.command.qualifiedId) { index, hit in
                    breadcrumbRow(hit: hit, isSelected: index == selection)
                }
                // Blank reserved slots between last result and slot 5 (spec: slot 5 never slides up).
                if let linkSlot = layout.showAllLinkSlot {
                    let blankSlots = linkSlot - 1 - layout.rows.count
                    ForEach(0 ..< max(blankSlots, 0), id: \.self) { _ in
                        Color.clear.frame(height: Self.rowHeight)
                    }
                    showAllRow
                }
            }
            if layout.scrolls {
                ScrollView { content }
                    .frame(height: Self.rowHeight * CGFloat(Self.slotCount))
            } else {
                content
                    .frame(height: Self.rowHeight * CGFloat(Self.slotCount), alignment: .top)
            }
        }
    }

    private func breadcrumbRow(hit: SearchHit, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "app.fill")
                .foregroundStyle(theme.textSecondary)
                .frame(width: 20)
            (
                Text(hit.command.addonId).foregroundStyle(theme.textSecondary)
                    + Text(" › ").foregroundStyle(theme.textSecondary)
                    + Text(hit.isSuggestion ? "\(hit.command.title) (did you mean this?)" : hit.command.title)
                    .foregroundStyle(theme.textPrimary).bold()
            )
            .font(JugnuTokens.font(presetId: store.presetId, role: .body))
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .background(isSelected ? theme.accent.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(hit.command) }
    }

    private var showAllRow: some View {
        Button(action: onOpenBrowseCatalog) {
            HStack {
                Text("Show all addons →")
                    .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                    .foregroundStyle(theme.accent)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [x] **Step 3: Build**

Run: `cd shell && swift build`
Expected: no errors.

---

### Task 10: Wire `FavoritesRow` + `SearchResultsRegion` into `PaletteView`, morph frame with result count  ✅ DONE

**Files:**
- Modify: `shell/Sources/JugnuUI/PaletteView.swift` (replace the existing inline `List` at lines 150-179 and the Browse/Preferences rows at 108-148 with `FavoritesRow` for row1 and `SearchResultsRegion` for the results, per spec §2's row1/row2 split)
- Modify: `shell/Sources/JugnuUI/ShellHost.swift` — no signature change needed; `morphFrame` already takes an optional explicit size input path via `ViewType`. Confirm whether a new `ViewType` case or explicit height override is needed — see Step 1.
- Modify: `shell/App/JugnuApp.swift:194-208` (`renderCurrentTop`'s `.launcher` case, and `ensurePanelIfNeeded`) to pass `model.topFavorites(limit: 5)`, `onReorder`, `onRemove` through to the new `PaletteView` init parameters
- Modify: `shell/Sources/JugnuUI/PaletteView.swift`'s `public init` to accept the new callbacks
- Test: `shell/Tests/JugnuUITests/ShellPresetTests.swift` — add a case asserting the growable-height math if a new `ViewType` size path is introduced (see Step 1 decision)

**Interfaces:**
- Consumes: `FavoritesRow` (Task 7), `SearchResultsRegion` (Task 9), `AppModel.topFavorites/moveFavorite/removeFavorite` (Task 5)
- Produces: `PaletteView.init` gains `favorites: [IndexedCommand]`, `onReorderFavorite: (Int, Int) -> Void`, `onRemoveFavorite: (IndexedCommand) -> Void` parameters (with sensible defaults so existing call sites in `JugnuApp.swift` don't all need to change in the same breath as a compile-error scramble — but per Global Constraints/no-placeholders, every call site is updated in this task, not left half-wired).

**Design decision needed before coding — read `ViewType.size(in:)` again (already read: `.palette` is a fixed `clamped(...)` band, not resizable per row count).** The spec (§2.1) wants the *same panel* to grow from row1+row2-only height to row1+row2+5-results height. Two ways to satisfy this with existing infra:
  (a) Keep `ShellPreset.launcher` mapped to `.seek`/`.palette` as today, and instead of a new `ViewType`, call `shellHost.morphFrame(to: .launcher, compactLauncher: false, on: screen, viewType: .palette)` (already fixed max height 360, which already fits row1+row2+5 result slots — verify with real numbers in Step 1) — no `ViewType` change needed, just a compactLauncher `true`/`false` toggle that already exists (`compactLauncher: query.isEmpty` when 0 results, `false` when ≥1 result). This matches the existing `seek`(empty, 120pt)/`palette`(has content, up to 360pt) split already wired via `ensurePanelIfNeeded`/`onChange(of: query)`.
  (b) Add height variants to `ViewType`. Rejected — bigger blast radius, not needed if (a)'s numbers work.

- [x] **Step 1: Verify option (a)'s numbers fit before writing any view code**

Run this arithmetic check as a quick throwaway test or by hand: row1 (favorites, ~40pt) + row2 (search bar, ~36pt with padding) + spacing (`JugnuTokens.Spacing.row` = 8, a few times) + results region (5 × 40pt = 200pt) + panel padding (14pt × 2) ≈ 40 + 36 + 24 + 200 + 28 = **328pt**, comfortably under `.palette`'s existing max height of 360pt (from `ViewType.swift`: `clamped(visible.height * 0.40, min: 280, max: 360)`). **Confirmed: option (a) fits.** No `ViewType` change needed. Skip straight to Step 2 with this approach.

- [x] **Step 2: Update `PaletteView.init` and body**

Replace lines 18-50 (struct properties + init) and 89-222 (body) in `PaletteView.swift`. Key changes:
- Add `favorites: [IndexedCommand]`, `onReorderFavorite: (Int, Int) -> Void`, `onRemoveFavorite: (IndexedCommand) -> Void` to both the struct's stored properties and `init`.
- Row1: `HStack { logoPlaceholder(); FavoritesRow(favorites: favorites, onRun: onRun, onReorder: onReorderFavorite, onRemove: onRemoveFavorite, onOpenAllFavorites: { onOpenBrowseCatalog(); onClose() }); prefsButton }` — logo is a placeholder (`Image(systemName: "sparkle")`) per Global Constraints (real icon is ticket 0051).
- Row2: keep the existing `TextField` exactly as-is (lines 91-106) — it already does what spec §2's row2 needs (placeholder rotation, query state).
- Below row2: replace the `List(...)` (lines 150-177) with `SearchResultsRegion(hits: displayed, selection: selection, onSelect: onRun, onOpenBrowseCatalog: { onOpenBrowseCatalog(); onClose() })`.
- **Drop** the standalone "Browse Addons" / "Preferences" buttons (old lines 108-148) — spec §2 replaces that first-view content with row1's favorites + the "…" icon (Favorites scope in viewB) and the row1 prefs button; Browse Addons as a full first-view row is superseded. Keep `onOpenPreferences` wired to the row1 prefs button only.
- Frame: change `.frame(width: 560, height: 360)` to a size that fits row1+row2 alone when `isFirstView && favorites.isEmpty` is false only in the sense of the *existing* compact/full split already handled upstream by `ensurePanelIfNeeded`/`JugnuApp.swift`'s `compactLauncher` flag — `PaletteView` itself doesn't decide its own frame (that's `ShellHost.morphFrame`, driven by `JugnuApp.swift`). Leave `PaletteView`'s own `.frame(...)` modifier as `.frame(maxWidth: 560, maxHeight: 360)` (change `width`/`height` to `maxWidth`/`maxHeight` so the view doesn't force a taller-than-needed layout when row1 is empty and there are 0 results) — the *outer panel* sizing is Step 3's job.

```swift
public struct PaletteView<Model: PaletteModelProtocol>: View {
    @ObservedObject var model: Model
    var favorites: [IndexedCommand]
    var onRun: (IndexedCommand) -> Void
    var onClose: () -> Void
    var onOpenBrowseCatalog: () -> Void
    var onOpenPreferences: () -> Void
    var onStateChange: (ShellViewState) -> Void
    var onReorderFavorite: (Int, Int) -> Void
    var onRemoveFavorite: (IndexedCommand) -> Void

    @State private var query: String
    @State private var selection = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var hintIndex = 0
    @State private var bloom: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeStore = ThemeStore.shared

    public init(
        model: Model,
        favorites: [IndexedCommand] = [],
        initialQuery: String = "",
        onRun: @escaping (IndexedCommand) -> Void,
        onClose: @escaping () -> Void,
        onOpenBrowseCatalog: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void,
        onStateChange: @escaping (ShellViewState) -> Void = { _ in },
        onReorderFavorite: @escaping (Int, Int) -> Void = { _, _ in },
        onRemoveFavorite: @escaping (IndexedCommand) -> Void = { _ in }
    ) {
        self.model = model
        self.favorites = favorites
        self.onRun = onRun
        self.onClose = onClose
        self.onOpenBrowseCatalog = onOpenBrowseCatalog
        self.onOpenPreferences = onOpenPreferences
        self.onStateChange = onStateChange
        self.onReorderFavorite = onReorderFavorite
        self.onRemoveFavorite = onRemoveFavorite
        _query = State(initialValue: initialQuery)
    }

    private var theme: JugnuThemeColors {
        JugnuThemeColors(theme: resolvedTheme(from: themeStore.config, colorScheme: colorScheme))
    }

    private var displayed: [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return model.commandsForFirstView().map {
                SearchHit(command: $0, tier: .title, score: 0, isSuggestion: false)
            }
        }
        return model.lastHits
    }

    private var placeholder: String {
        if model.allCommands.isEmpty {
            return "No addons yet — install some to get started."
        }
        let commands = model.allCommands
        guard !commands.isEmpty else { return "Search commands" }
        let cmd = commands[hintIndex % commands.count]
        let hint = cmd.keywords.first ?? cmd.title.split(separator: " ").prefix(2).joined(separator: " ")
        return "Try '\(hint)'…"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            // Row1: logo (left, placeholder) + favorites (center) + prefs (right) — spec §2, fixed geometry.
            HStack {
                Image(systemName: "sparkle")
                    .foregroundStyle(theme.accent)
                FavoritesRow(
                    favorites: favorites,
                    onRun: onRun,
                    onReorder: onReorderFavorite,
                    onRemove: onRemoveFavorite,
                    onOpenAllFavorites: { onOpenBrowseCatalog(); onClose() }
                )
                Button(action: { onOpenPreferences(); onClose() }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("All addons + preferences")
            }

            // Row2: search bar — unchanged from before this task.
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(JugnuTokens.font(presetId: themeStore.presetId, role: .title3))
                .padding(8)
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: query) { _, newValue in
                    onStateChange(.launcher(query: newValue, selection: nil, scroll: 0))
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        guard !Task.isCancelled else { return }
                        _ = model.search(newValue)
                        selection = 0
                    }
                }

            SearchResultsRegion(
                hits: displayed,
                selection: selection,
                onSelect: onRun,
                onOpenBrowseCatalog: { onOpenBrowseCatalog(); onClose() }
            )

            if let status = model.statusMessage {
                PanelErrorBanner(message: status)
            }
        }
        .padding(JugnuTokens.Spacing.panelPadding)
        .frame(maxWidth: 560, maxHeight: 360)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.2 + bloom * 0.5), lineWidth: 1.5)
                .shadow(color: theme.accent.opacity(bloom), radius: 18)
        )
        .focusable()
        .onAppear {
            _ = model.search(query)
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                withAnimation(.easeOut(duration: 0.12)) { bloom = 0.35 }
                withAnimation(.easeIn(duration: 0.18).delay(0.12)) { bloom = 0 }
            }
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if query.isEmpty, !model.allCommands.isEmpty {
                hintIndex += 1
            }
        }
        .onKeyPress(.return) {
            guard displayed.indices.contains(selection) else { return .handled }
            onRun(displayed[selection].command)
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !displayed.isEmpty {
                selection = min(selection + 1, displayed.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
    }
}
```

Note: `isFirstView`/`showBrowseCatalogRow`/`showPreferencesRow` computed properties are removed — no longer needed since Browse/Preferences are now row1 icons, not first-view list rows.

- [x] **Step 3: Update `JugnuApp.swift` call sites**

In `ensurePanelIfNeeded` (line ~180) and `renderCurrentTop`'s `.launcher` case (line ~200), pass the new parameters:

```swift
    private func ensurePanelIfNeeded(model: AppModel) {
        guard let shellHost else { return }
        shellHost.ensurePanel(
            initialContent: PaletteView(
                model: model,
                favorites: model.topFavorites(limit: 5),
                onRun: { [weak self] cmd in self?.runCommand(cmd) },
                onClose: { [weak shellHost] in shellHost?.hide() },
                onOpenBrowseCatalog: { [weak self] in self?.pushCatalog() },
                onOpenPreferences: { [weak self] in self?.pushSettings() },
                onReorderFavorite: { [weak self] from, to in self?.model?.moveFavorite(from: from, to: to) },
                onRemoveFavorite: { [weak self] cmd in self?.model?.removeFavorite(qualifiedId: cmd.qualifiedId) }
            ),
            size: ShellPreset.launcher.size(compactLauncher: false)
        )
    }
```

```swift
        case .launcher:
            guard case .launcher(let query, _, _) = shellHost.stack.top.state else { return }
            shellHost.setContent(PaletteView(
                model: model,
                favorites: model.topFavorites(limit: 5),
                initialQuery: query,
                onRun: { [weak self] cmd in self?.runCommand(cmd) },
                onClose: { [weak shellHost] in shellHost?.hide() },
                onOpenBrowseCatalog: { [weak self] in self?.pushCatalog() },
                onOpenPreferences: { [weak self] in self?.pushSettings() },
                onStateChange: { [weak shellHost] state in shellHost?.updateTopState(state) },
                onReorderFavorite: { [weak self] from, to in self?.model?.moveFavorite(from: from, to: to) },
                onRemoveFavorite: { [weak self] cmd in self?.model?.removeFavorite(qualifiedId: cmd.qualifiedId) }
            ))
```

Adjust `self?.model?` to whatever the actual optional-chaining shape is in `JugnuApp.swift` — verify `model`'s declared type (`AppModel?` vs. non-optional) by re-reading the surrounding `AppDelegate` class before editing; `runCommand`'s own `guard let model` pattern earlier in the file is the reference (`private func runCommand` at the top of the read excerpt has `guard let model, let shellHost else { return }` — copy that guard style into these two closures if `model`/`shellHost` are implicitly-unwrapped rather than plain optionals).

- [x] **Step 4: Build**

Run: `cd shell && swift build 2>&1 | tail -50`
Expected: no errors. Fix any remaining call-site mismatches (e.g. if `AppDelegate` holds `model` as non-optional `AppModel!`, drop the `?.` accordingly).

- [x] **Step 5: Run full test suite**

Run: `cd shell && swift test 2>&1 | tail -80`
Expected: all pass, including `ShellPresetTests` (Task 3), `StateStoreTests` (Task 4), `FavoritesRowLogicTests` (Task 6), `SearchResultsRegionLogicTests` (Task 8), `JugnuThemeColorsTests` (Task 2), `ThemeConfigTests` (Task 1).

---

### Task 11: Manual smoke pass + `shell-smoke.md` update  ⏳ smoke doc drafted; interactive walk pending on your Mac

**Files:**
- Modify: `docs/architecture/shell-smoke.md` (add a new checklist section for this phase's changes, following that file's existing format — read it first to match the format exactly)

**Interfaces:** None (manual verification task, no code).

- [x] **Step 1: Read the existing smoke checklist format**

Run: `cat docs/architecture/shell-smoke.md` (or `head -60` if long) to see the existing section structure before appending — match its exact heading/checkbox style.

- [x] **Step 2: Build and run the app locally**

Run: `cd shell && swift build` then launch the built `Jugnu.app` (or via `open` on the Xcode-built product — follow whatever the existing smoke doc says for "how to launch" in its current content).

- [x] **Step 3: Walk this phase's behaviors on a real Mac**

- [ ] 0 favorites: row1 center is blank, no placeholder text, logo/prefs stay in place.
- [ ] Favorite a command (star icon still lives in `SearchResultsRegion`'s row today? — **note:** this phase's `SearchResultsRegion` breadcrumb row does not include a favorite-star toggle button; the old `PaletteView` had one inline in its `List` row (lines 166-173 of the pre-Task-10 file) — carry it forward into `breadcrumbRow` in Task 9 if it's missing, since removing the *only* way to add a favorite from search results would be a regression the spec doesn't call for (spec §2's "card-star-only" rule for *adding* favorites refers to viewB's card, which doesn't exist yet in this phase — until it does, search-results is the only add-favorite entry point and must keep working). **Fix now if missing before continuing smoke.**
- [ ] Favoriting via search-results star updates row1 within the same session.
- [ ] Row1 shows top 5 favorites in the stored order; a 6th favorited command shows the "…" icon.
- [ ] Drag-reorder two favorites in row1; confirm the new order persists after closing/reopening the palette (Opt+Space twice).
- [ ] Right-click a row1 favorite → "Remove from Favorites" removes it without confirmation.
- [ ] Type a query with 0 results: did-you-mean suggestion (if any installed command matches) shows in slot 1, "Show all addons" link still shows.
- [ ] Type a query with exactly 4 results: 4 rows + "Show all addons" link, no scrollbar.
- [ ] Type a query with >4 results: scrollable region, no "Show all addons" link visible without scrolling past all results.
- [ ] Panel height stays visually stable while typing (no jarring resize per keystroke — confirms the fixed-5-slot rule is working, not a per-query resize).
- [ ] Catalog / Detail / Preferences panels open at the new (larger, canvas-sized) dimensions without visual clipping — full redesign is a later phase, but confirm nothing is now broken/cut-off by the `.canvas` remap alone.

- [x] **Step 4: Append results to `shell-smoke.md`**

Follow the existing file's format; note pass/fail per item and the date.

---

## Self-Review Notes

**Spec coverage check (§1, §2, §2.1, §4 — this plan's scope):**
- §1 canvas remap for catalog/detail/settings → Task 3. ✅
- §2 row1 (logo/favorites/prefs, empty state, reorder, remove, click-to-run) → Tasks 4–7, 10. ✅ (state icon lit/dim is explicitly deferred — no per-addon state source exists yet; flagged inline, not silently dropped)
- §2 row2 (search bar, placeholder rotation) → unchanged, already existed, kept as-is in Task 10. ✅
- §2.1 search-results transition (fixed 5-slot, breadcrumb rows, did-you-mean, show-all link) → Tasks 8–10. ✅
- §4 new tokens (`subText` real field; `border`/`surface2`/`accentDeep` derived) → Tasks 1–2. ✅
- §3/§3.1–§3.4 (viewB rail, scope, tags, cards, detail view tabs/gallery/genie, prefs rail content) → explicitly **out of scope**, later phases per user's phased-plan request.
- §5 icon system → explicitly deferred to ticket 0051, placeholders used throughout per Global Constraints.

**Known follow-ups surfaced during planning (not silently dropped, not blocking this phase):**
- Favorite-star toggle in search results must be preserved when building Task 9's `breadcrumbRow` — flagged explicitly in Task 11 Step 3 as a build-time check, not deferred to phase 2, since removing it now would break existing favorite-adding functionality with no replacement in this phase.
- Per-addon live on/off state (row1 icon lit/dim) has no data source yet — real fix likely needs a shell↔addon state-reporting mechanism, which is bigger than this phase; flagged in Task 7 with an inline comment rather than faked.
- `SearchResultsRegion`'s breadcrumb addon-name half uses raw `addonId`, not a resolved display name — flagged in Task 9 Step 1 as a possible follow-on after manual smoke.
