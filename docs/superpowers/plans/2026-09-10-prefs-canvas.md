# Preferences Canvas (0064) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Ship Preferences as a `canvas` rail + content panes (Theme / Addons→Updates / General) with real settings only; remove catalog lifecycle controls from prefs.

**Architecture:** Selection enum in JugnuCore; `PrefsView` in JugnuUI (rail + preference rows + theme editors); App wires config bindings and Check for Updates. Keep `ShellPreset.settings` / `pushSettings()`. No Hotkeys / Installed / Permissions rows.

**Tech Stack:** Swift / SwiftUI, JugnuCore + JugnuUI + App, XCTest.

**Spec:** [docs/architecture/2026-09-10-prefs-canvas-design.md](../../architecture/2026-09-10-prefs-canvas-design.md)

## Global Constraints

- **Git:** do not run git, do not branch, do not commit (`AGENTS.md`). Mark steps done after tests pass.
- **Every task ships green.** End each task with `cd shell && swift test` (or filtered) green before the next.
- **Prefs = settings only.** No enable/disable, uninstall, Install starter addons, or Browse Catalog… in prefs.
- **Rail this epic only:** Theme · Addons→Updates · General. Default selection: Theme.
- **Layering:** JugnuUI takes descriptors/bindings/closures — not `AppModel`. Move `PrefsView` out of `shell/App/`.
- **Not this plan:** 0065 detail tabs, 0066 Open/primary, 0037 Hotkeys, 0054 B Permissions inventory, shared Browse/Prefs rail extraction.

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `shell/Sources/JugnuCore/Prefs/PrefsSelection.swift` | 1 | `PrefsSelection` enum + `addonsExpanded` helper if needed |
| `shell/Tests/JugnuCoreTests/PrefsSelectionTests.swift` | 1 | Default / cases |
| `shell/Sources/JugnuUI/PreferenceRow.swift` | 2 | Label + optional description + trailing control |
| `shell/Tests/JugnuUITests/PreferenceRowTests.swift` | 2 | Smoke / layout host if useful; otherwise ViewInspect-free compile via PrefsView tests |
| `shell/Sources/JugnuUI/PrefsView.swift` | 3 | Rail + panes; theme / updates / general |
| `shell/Tests/JugnuUITests/PrefsViewTests.swift` | 3 | Selection switches; no lifecycle buttons |
| `shell/App/PrefsView.swift` | 4 | Delete after move |
| `shell/App/JugnuApp.swift` | 4 | Wire new `PrefsView` API (no `onOpenCatalog`) |
| `shell/Jugnu.xcodeproj/project.pbxproj` | 4 | Drop App `PrefsView.swift` file ref |
| `docs/architecture/shell-smoke.md` | 5 | Retarget prefs paths; catalog owns lifecycle |
| `CHANGELOG.md`, `docs/tickets.md` | 5 | Ship notes; 0064 In progress→Done when code green |

---

## Task 1 — `PrefsSelection`

**Files:**
- Create: `shell/Sources/JugnuCore/Prefs/PrefsSelection.swift`
- Test: `shell/Tests/JugnuCoreTests/PrefsSelectionTests.swift`

**Produces:** `public enum PrefsSelection: String, CaseIterable, Equatable, Sendable` with cases `theme`, `addonsUpdates`, `general`.

- [x] **Step 1: Write failing tests**

```swift
import XCTest
import JugnuCore

final class PrefsSelectionTests: XCTestCase {
    func testCasesAreStable() {
        XCTAssertEqual(
            PrefsSelection.allCases.map(\.rawValue),
            ["theme", "addonsUpdates", "general"]
        )
    }

    func testDefaultIsTheme() {
        XCTAssertEqual(PrefsSelection.default, .theme)
    }
}
```

- [x] **Step 2:** `cd shell && swift test --filter PrefsSelectionTests` — FAIL (type missing).

- [x] **Step 3: Implement**

```swift
public enum PrefsSelection: String, CaseIterable, Equatable, Sendable {
    case theme
    case addonsUpdates
    case general

    public static let `default`: PrefsSelection = .theme
}
```

- [x] **Step 4:** `cd shell && swift test --filter PrefsSelectionTests` — PASS.

---

## Task 2 — Preference row chrome

**Files:**
- Create: `shell/Sources/JugnuUI/PreferenceRow.swift`

**Produces:** `PreferenceRow` view used by all prefs panes.

- [x] **Step 1: Implement** (no separate test file required if Task 3 covers usage)

```swift
import SwiftUI

public struct PreferenceRow<Control: View>: View {
    let title: String
    let description: String?
    @ViewBuilder var control: () -> Control

    public init(title: String, description: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.description = description
        self.control = control
    }

    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 8)
    }
}
```

Use `JugnuTokens` / theme colors when wiring inside `PrefsView` (Task 3) rather than hard-coding `.secondary` if neighboring rows already theme captions.

- [x] **Step 2:** `cd shell && swift build --target JugnuUI` — PASS.

---

## Task 3 — `PrefsView` in JugnuUI (rail + panes)

**Files:**
- Create: `shell/Sources/JugnuUI/PrefsView.swift`
- Test: `shell/Tests/JugnuUITests/PrefsViewTests.swift`

**Consumes:** `PrefsSelection`, `PreferenceRow`, existing `JugnuThemeColors` / `ThemeStore` / `JugnuTokens` / `PanelErrorBanner` / `JugnuPresets` patterns from App’s current `PrefsView`.

**Produces:** Public `PrefsView` that does **not** take `AppModel` or `ShellHost`.

API shape:

```swift
public struct PrefsView: View {
    public var themeConfig: Binding<ThemeConfig>
    public var sound: Binding<Bool>
    public var firstView: Binding<PaletteFirstView>
    public var keepAppCurrent: Binding<Bool>
    public var keepAddonsCurrent: Binding<Bool>
    public var shellVersion: String
    public var registryURL: String
    public var errorText: String?
    public var onCheckForUpdates: () -> Void
    public var onClose: () -> Void
    public var onApplyPreset: (ThemeConfig) -> Void
    // Color editors: either pass Binding<ThemeConfig> only (mutate via themeConfig) 
    // or discrete setters — prefer single themeConfig Binding.
}
```

Migrate theme preview + light/dark `ColorPicker` rows from `shell/App/PrefsView.swift` into this view (same behavior).

**Rail UI:**
- List or `VStack` of rows: Theme; Addons (tap expands to show indented Updates); General.
- Selecting Updates sets `selection = .addonsUpdates` and keeps Addons expanded.
- Selecting Theme / General collapses Addons or leaves expanded — either OK; prefer keep expanded once opened.
- Active row: left accent bar (match catalog sidebar if cheap; else opacity/bold).

**Content:**
- `.theme` → presets + preview + editors
- `.addonsUpdates` → version, keep toggles, Check for Updates, registry caption
- `.general` → sound, first-view picker

**Must not include:** ForEach of addon ids, Enable toggle, Uninstall, Install starter, Browse Catalog.

- [x] **Step 1: Write failing tests** (ViewInspector not required — test a small pure helper if extracted, e.g. titles for selection):

```swift
func testPaneTitle() {
    XCTAssertEqual(PrefsPaneTitle.title(for: .theme), "Theme")
    XCTAssertEqual(PrefsPaneTitle.title(for: .addonsUpdates), "Updates")
    XCTAssertEqual(PrefsPaneTitle.title(for: .general), "General")
}
```

Put `PrefsPaneTitle` in the same file as `PrefsView` or a tiny Core helper.

- [x] **Step 2:** Implement `PrefsView` + titles; run `swift test --filter PrefsPaneTitle` or `PrefsViewTests` — PASS.

- [x] **Step 3:** Full `cd shell && swift test` — PASS (App still points at old PrefsView until Task 4).

---

## Task 4 — App wiring + delete old prefs

**Files:**
- Modify: `shell/App/JugnuApp.swift` (`case .settings`)
- Delete: `shell/App/PrefsView.swift`
- Modify: `shell/Jugnu.xcodeproj/project.pbxproj` — remove App PrefsView file reference / build file

**Wire:**

```swift
case .settings:
    shellHost.setContent(PrefsView(
        themeConfig: Binding(
            get: { model.config.theme },
            set: { newTheme in
                var c = model.config
                c.theme = newTheme
                try? model.saveConfig(c)
            }
        ),
        sound: /* same pattern as old soundBinding */,
        firstView: /* … */,
        keepAppCurrent: /* … */,
        keepAddonsCurrent: /* … */,
        shellVersion: ShellVersion.current,
        registryURL: model.config.shell.registryURL,
        errorText: model.statusMessage,
        onCheckForUpdates: { [weak self] in
            Task { await self?.keepCurrent?.checkManual() }
        },
        onClose: { [weak self] in self?.popOrDismiss() },
        onApplyPreset: { preset in
            var c = model.config
            c.theme = preset
            try? model.saveConfig(c)
        }
    ))
```

Drop `onOpenCatalog` entirely from settings content.

Remove any App helpers that only existed for prefs addon enable/uninstall UI (keep `DisableWhileTracked` / uninstall presenters for catalog).

- [x] **Step 1:** Switch call site; delete App `PrefsView.swift`; fix pbxproj.
- [x] **Step 2:** `cd shell && swift test` — PASS.
- [x] **Step 3:** Grep confirms no `Install starter addons` / prefs `Uninstall` / `onOpenCatalog` in prefs path.

---

## Task 5 — Docs + ticket Done

**Files:**
- `docs/architecture/shell-smoke.md`
- `CHANGELOG.md`
- `docs/tickets.md` (0064 → Done when shipped)
- Spec status → Approved if still Draft

**Smoke edits:**
- Theme / sound / keep-current: say **Preferences → Theme / General / Addons → Updates**.
- Move “Install starter addons” / disable-uninstall-from-Preferences items to **Browse Catalog** wording (or drop if duplicated under catalog sections).
- Clipboard-history enable/disable: retarget to catalog card, not Preferences.

**CHANGELOG:** one Added line for prefs canvas (0064).

- [x] **Step 1:** Doc edits.
- [x] **Step 2:** `cd shell && swift test` — PASS.
- [x] **Step 3:** Mark plan checkboxes done; 0064 Done in tickets.

---

## Spec coverage

| Spec requirement | Task |
|---|---|
| Canvas rail + header Preferences + ✕ | 3, 4 |
| Theme / Addons→Updates / General only | 1, 3 |
| Default Theme | 1, 3 |
| Migrate theme / sound / first view / keep-current | 3, 4 |
| Remove enable/uninstall/starter/Browse from prefs | 3, 4 |
| PrefsView in JugnuUI | 3, 4 |
| No Hotkeys/Installed/Permissions rows | 3 |
| Smoke + CHANGELOG + tickets | 5 |

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-09-10-prefs-canvas.md`.

**1. Subagent-Driven (recommended)** — fresh subagent per task  
**2. Inline Execution** — this session  

Which approach?
