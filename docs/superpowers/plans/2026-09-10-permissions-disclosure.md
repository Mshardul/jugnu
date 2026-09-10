# Permissions Disclosure (0038) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Now / ticket 0038 — closed `permissions` on manifests and registry, card/detail surfaces, and confirm-before-write for catalog Install, Update (grew), first-launch Continue, and keep-current bulk when capabilities grew.

**Architecture:** JugnuCore owns the closed capability enum, parse/normalize/grew/union-expand, `UIDescriptor` message builders, and registry/manifest fields. App confirms from **registry data before download** (and from installed `addon.yaml` for grew), hosts in-panel confirms via `ShellHost.pushFollowUp` + `CheckedContinuation`, and hosts first-launch confirm inside `FirstRunWindow`. JugnuUI renders card one-liner and detail list. Do not invent a second installer. Do not ship 0054 A/B or 0022.

**Tech Stack:** Swift / JugnuCore + JugnuUI + App, Yams manifests, existing `UIDescriptor` `.confirm`, XCTest, `scripts/validate-addon.sh`, `scripts/build-registry.sh`.

**Spec:** [docs/architecture/2026-09-10-permissions-disclosure-design.md](../../architecture/2026-09-10-permissions-disclosure-design.md) — **Now / 0038 only**.

## Global Constraints

- **Git:** do not run git, do not branch, do not commit (`AGENTS.md`). Skip every “Commit” instinct; mark steps done after tests pass.
- **Every phase ships green.** End each phase with `cd shell && swift test` green before starting the next.
- **Honor the locked tables** in the spec (§2–§4): closed ids; clipboard = any pasteboard; confirm if non-empty; grew-only on update; multi = unique titles + nested addon names; first-launch confirm stays in the first-launch window; catalog confirms use KeyablePanel.
- **Layering:** parse / grew / union / `UIDescriptor` builders stay in **JugnuCore**. Panel hosting / first-launch UI / wiring stay in **App**. Card/detail rendering in **JugnuUI**. No AppKit in Core.
- **Confirm before download:** for catalog Install/Update/first-launch, build the disclosure from `RegistryEntry.permissions` (and catalog neighbors for multi) **before** `AddonInstaller.install`. Nested addon names under each capability are always visible in the message (no interactive DisclosureGroup required in `ConfirmView` for Now). First-launch may use `DisclosureGroup` optionally; nested text is enough.
- **Deps merge:** when `DependencyPlan.needsDisclosure` and permissions are non-empty, one message: capabilities block first, then the existing dep lines (“already installed” / “will be installed” / installed ≠ enabled). Migrate `DependencyInstallDisclosure` NSAlert to the same in-panel presenter when both or either need a sheet.
- **Not this plan:** pre-TCC explainer (0054 A), prefs Permissions page (0054 B), TCC reset (0022), glyphs (0051), sandboxing (0021), free-text reasons, binary inference.

---

## File map

| Path | Phase | Responsibility |
|---|---|---|
| `shell/Sources/JugnuCore/Permissions/AddonPermission.swift` | 1 | Closed enum, display title, reason, sort order, TCC vs capability |
| `shell/Sources/JugnuCore/Permissions/PermissionsSet.swift` | 1 | parse list, normalize/dedupe, grew, needsLine, union+expand |
| `shell/Sources/JugnuCore/Permissions/PermissionsConfirmation.swift` | 1 | `confirmPermissionsInstallUI` / multi / grew / combined-with-deps message builders |
| `shell/Sources/JugnuCore/Models.swift` | 1 | `AddonManifest.permissions` |
| `shell/Sources/JugnuCore/RegistryClient.swift` | 1 | `RegistryEntry.permissions` |
| `shell/Sources/JugnuCore/ManifestLoader.swift` | 1 | Reject unknown ids after decode |
| `shell/Sources/JugnuCore/UserFacingError.swift` | 1 | Unknown-permission copy |
| `scripts/validate-addon.sh` | 2 | Reject unknown `permissions:` tokens |
| `scripts/build-registry.sh` | 2 | Emit `permissions` from each manifest into `addons.json` |
| `addons/jugnu.*/addon.yaml` | 2 | First-party table fills |
| `shell/App/InstallDisclosurePresenter.swift` | 3 | Awaitable in-panel confirm (`pushFollowUp` + continuation) |
| `shell/App/BrowseCatalogViewModel.swift` | 3–4 | Pre-download confirm; grew on Update; retire NSAlert deps |
| `shell/App/DaemonAgents.swift` | 3 | Remove or thin `DependencyInstallDisclosure` (logic moves to Core message + presenter) |
| `shell/App/FirstRunWindow.swift` | 4 | Confirm before `onFinish` / Continue |
| `shell/App/KeepCurrentCoordinator.swift` | 5 | Bulk confirm includes capability growths |
| `shell/Sources/JugnuUI/AddonCardView.swift` | 6 | `Needs …` line |
| `shell/Sources/JugnuUI/AddonDetailView.swift` | 6 | Permissions list + empty copy |
| `docs/addon-manifest.md`, `PRIVACY.md`, `shell-smoke.md`, `CHANGELOG.md`, `tickets.md` | 7 | Docs + smoke |

---

## Phase 1 — Core contract (no UI host)

**Ships:** enum, parse, grew, union/expand, manifest + registry fields, loader refuse, `UIDescriptor` builders, tests.

### 1.1 `AddonPermission` + `PermissionsSet`

**Files:**
- Create: `shell/Sources/JugnuCore/Permissions/AddonPermission.swift`
- Create: `shell/Sources/JugnuCore/Permissions/PermissionsSet.swift`
- Test: `shell/Tests/JugnuCoreTests/PermissionsSetTests.swift`

- [ ] **Step 1:** Write failing tests for parse (known ids), unknown id throws, dedupe + display order, `grew(from:to:)`, `needsLine`, `unionExpand`.

```swift
public enum AddonPermission: String, Codable, CaseIterable, Sendable, Equatable {
    case accessibility
    case inputMonitoring = "input-monitoring"
    case camera
    case microphone
    case screenRecording = "screen-recording"
    case network
    case clipboard
    case background

    public var displayTitle: String { /* Accessibility, Input Monitoring, … */ }
    public var reason: String { /* spec §3.1 */ }
    public var isTCC: Bool { /* first five true */ }
    public static var displayOrder: [AddonPermission] { Array(allCases) /* declaration order */ }
}

public enum PermissionsParseError: Error, Equatable {
    case unknown(String)
}

public enum PermissionsSet {
    /// Parse raw strings; unknown → throw; dedupe; sort by `displayOrder`.
    public static func parse(_ raw: [String]) throws -> [AddonPermission]

    /// `new.subtracting(old)` in display order. Empty old = all of new.
    public static func grew(from old: [AddonPermission], to new: [AddonPermission]) -> [AddonPermission]

    public static func needsLine(_ permissions: [AddonPermission]) -> String?
    // "Needs Accessibility, Clipboard" or nil if empty

    /// Unique permissions in display order; map each → addon names (stable name sort).
    public static func unionExpand(
        addons: [(name: String, permissions: [AddonPermission])]
    ) -> [(permission: AddonPermission, addonNames: [String])]
}
```

```swift
func testParseUnknownThrows() {
    XCTAssertThrowsError(try PermissionsSet.parse(["clipboard", "telepathy"])) { err in
        XCTAssertEqual(err as? PermissionsParseError, .unknown("telepathy"))
    }
}

func testGrewOnlyNewIds() throws {
    let old = try PermissionsSet.parse(["clipboard"])
    let new = try PermissionsSet.parse(["clipboard", "accessibility"])
    XCTAssertEqual(PermissionsSet.grew(from: old, to: new), [.accessibility])
}

func testUnionExpandGroupsNames() throws {
    let rows = PermissionsSet.unionExpand(addons: [
        (name: "Clip Tools", permissions: [.clipboard]),
        (name: "Weather", permissions: [.network]),
        (name: "History", permissions: [.clipboard, .background]),
    ])
    XCTAssertEqual(rows.map(\.permission), [.network, .clipboard, .background] /* display order */)
    // Assert clipboard names == ["Clip Tools", "History"] sorted
}
```

- [ ] **Step 2:** Implement until tests pass.

- [ ] **Step 3:** `cd shell && swift test --filter PermissionsSetTests` green.

### 1.2 Manifest + registry + loader

**Files:**
- Modify: `shell/Sources/JugnuCore/Models.swift` (`AddonManifest`)
- Modify: `shell/Sources/JugnuCore/RegistryClient.swift` (`RegistryEntry`)
- Modify: `shell/Sources/JugnuCore/ManifestLoader.swift`
- Modify: `shell/Sources/JugnuCore/UserFacingError.swift`
- Test: extend `ManifestLoaderTests.swift`, `RegistryClientTests.swift`

- [ ] **Step 1:** Failing tests: yaml with `permissions: [clipboard, background]` loads; unknown id → `ManifestLoaderError.unknownPermission`; omit → `[]`; registry JSON missing key → `[]`; registry with permissions decodes.

```swift
// AddonManifest
public var permissions: [AddonPermission]  // default []

// CodingKeys add `permissions`
// Decode: raw [String] via PermissionsSet.parse; map PermissionsParseError → ManifestLoaderError.unknownPermission
// Encode: omit if empty; encode rawValue strings

// RegistryEntry
public var permissions: [AddonPermission] = []
// Decode ifPresent [String] → parse (invalid catalog → RegistryClientError.invalidCatalog or empty+skip? Prefer: hard-fail invalid catalog on unknown id so bad registry is visible)
```

Lock: **unknown permission in registry JSON → `RegistryClientError.invalidCatalog`** (same as malformed catalog). Unknown in `addon.yaml` → `ManifestLoaderError.unknownPermission`.

```swift
case unknownPermission(String)  // on ManifestLoaderError
```

UserFacingError: `"This addon’s description couldn’t be read. Try reinstalling it."` for unknownPermission (same family as other manifest corruption).

- [ ] **Step 2:** Implement decode/encode + loader validation after YAML decode (call `PermissionsSet.parse` on raw if stored as strings, or validate during decode).

- [ ] **Step 3:** Update every `AddonManifest(` test fixture initializer call site that breaks — add `permissions: []` default in the memberwise init so most call sites compile unchanged.

- [ ] **Step 4:** `cd shell && swift test` green.

### 1.3 Confirm message builders

**Files:**
- Create: `shell/Sources/JugnuCore/Permissions/PermissionsConfirmation.swift`
- Test: `shell/Tests/JugnuCoreTests/PermissionsConfirmationTests.swift`

- [ ] **Step 1:** Failing tests for exact titles/labels and message substrings.

```swift
public func confirmPermissionsInstallUI(addonName: String, permissions: [AddonPermission]) -> UIDescriptor
// title: "Install {name}?"
// message: "This addon will need:\n• Accessibility\n• Clipboard"
// confirmLabel: "Install", cancelLabel: "Cancel"

public func confirmPermissionsMultiUI(
    expand: [(permission: AddonPermission, addonNames: [String])]
) -> UIDescriptor
// title: "Install these addons?"
// message: "They will need:\nAccessibility\n  • Window Layouts\nClipboard\n  • Clip Tools\n  • History"
// confirmLabel: "Install", cancelLabel: "Cancel"

public func confirmPermissionsGrewUI(addonName: String, newPermissions: [AddonPermission]) -> UIDescriptor
// title: "Update {name}?"
// message: "This version newly needs:\n• Accessibility"
// confirmLabel: "Update", cancelLabel: "Cancel"

public func confirmInstallDisclosureUI(
    permissionsTitle: String,           // e.g. "Install Mic Mute?" or multi title
    permissionsBody: String?,           // nil if no capabilities
    dependencyPlan: DependencyPlan?     // nil if no deps
) -> UIDescriptor
// If both: capabilities block, blank line, then dep lines matching today’s DependencyInstallDisclosure copy
// confirmLabel Install or Update as caller chooses via parameter `confirmLabel`
```

Dep block copy (match existing):

```
This will also handle these addons:
• {name} — already installed
• {name} — will be installed now

Installed is not the same as enabled. You’ll enable each addon yourself.
```

- [ ] **Step 2:** Implement builders using `UIDescriptor(pattern: .confirm, ...)`.

- [ ] **Step 3:** `cd shell && swift test --filter PermissionsConfirmationTests` green. Phase 1 Done when full `swift test` green.

---

## Phase 2 — Packaging + first-party yaml + registry emit

**Ships:** validate-addon, yaml fills per spec §3.5, `build-registry` writes `permissions` into `registry/addons.json`.

### 2.1 validate-addon.sh

**Files:** Modify `scripts/validate-addon.sh`

- [ ] **Step 1:** Add awk/bash block (same style as `helpers:`) that, when `permissions:` is present, accepts only:

`accessibility|input-monitoring|camera|microphone|screen-recording|network|clipboard|background`

Reject unknown with `invalid permission: …` on stderr, exit 1. Empty list OK. Missing key OK.

- [ ] **Step 2:** Run `scripts/validate-addon.sh addons/jugnu.mic-mute` (still passes with no field). Manually verify a throwaway unknown fails (do not leave the throwaway in tree).

### 2.2 First-party `addon.yaml` fills

**Files:** Modify the addons in spec §3.5 that need non-empty lists:

| File | Add |
|---|---|
| `addons/jugnu.window-layouts/addon.yaml` | `permissions: [accessibility]` |
| `addons/jugnu.clipboard-history/addon.yaml` | `permissions: [clipboard, background]` |
| `addons/jugnu.clip-tools/addon.yaml` | `permissions: [clipboard]` |
| `addons/jugnu.paste-plain/addon.yaml` | `permissions: [clipboard]` |
| `addons/jugnu.weather-bar/addon.yaml` | `permissions: [network]` |
| `addons/jugnu.brew-outdated/addon.yaml` | `permissions: [network]` |
| `addons/jugnu.keep-awake/addon.yaml` | `permissions: [background]` |

Leave others without the key (none).

- [ ] **Step 1:** Apply the yaml edits.
- [ ] **Step 2:** `scripts/validate-addon.sh` on each edited addon — all pass.

### 2.3 build-registry.sh emit

**Files:** Modify `scripts/build-registry.sh`

- [ ] **Step 1:** When packaging each addon, read permissions from the manifest (python or awk list under `permissions:`). Include `"permissions": ["clipboard", …]` on each new JSON entry (use `[]` when absent). Preserve hand-authored catalog fields as today; **do not** preserve old permissions from existing registry — always take from manifest so the table wins.

- [ ] **Step 2:** Run `scripts/build-registry.sh dist https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0` (or repo’s usual base URL). Confirm `registry/addons.json` rows for clip-tools / weather-bar / keep-awake contain the expected arrays. **Do not** `gh release upload` unless the user explicitly asks (AGENTS.md).

- [ ] **Step 3:** Phase 2 Done. Note: republishing zips to GitHub is a **release** follow-up, not required to close Core tests.

---

## Phase 3 — In-panel confirm presenter + Browse Install/Update

**Ships:** awaitable panel confirm; catalog Install confirms before download; Update confirms only when grew; dep disclosure uses the same presenter (no NSAlert).

### 3.1 `InstallDisclosurePresenter`

**Files:**
- Create: `shell/App/InstallDisclosurePresenter.swift`
- Test: `shell/Tests/JugnuAppTests/InstallDisclosurePresenterTests.swift` only if pure helpers are extractable; otherwise manual smoke. Prefer testing Core builders (already done) and keep presenter thin.

```swift
@MainActor
enum InstallDisclosurePresenter {
    /// Presents `ui` on `shellHost` and resumes with true/false.
    static func confirm(ui: UIDescriptor, shellHost: ShellHost, commandId: String) async -> Bool
}
```

Implementation sketch:

```swift
await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
    var resumed = false
    func finish(_ value: Bool) {
        guard !resumed else { return }
        resumed = true
        cont.resume(returning: value)
    }
    shellHost.setOnCancel { finish(false) }
    shellHost.onCancelFollowUp = { finish(false) }
    shellHost.pushFollowUp(
        ui: ui,
        commandId: commandId,
        trace: nil,
        onScreen: shellHost.currentScreen ?? NSScreen.main!,
        followUp: { _ in
            finish(true)
            return RunResponse(ok: true)
        }
    )
    shellHost.orderFront()
}
```

Arm click-outside to cancel (same as keep-current confirms). Ensure `finish` is once-only.

- [ ] **Step 1:** Implement presenter.
- [ ] **Step 2:** Compile App target (`cd shell && swift test` still green).

### 3.2 Browse Install — pre-download permissions (+ deps from registry)

**Files:** Modify `shell/App/BrowseCatalogViewModel.swift`; thin `DependencyInstallDisclosure` in `DaemonAgents.swift`.

- [ ] **Step 1:** Before `model.installer.install` in `install(_:)`:

1. Let `perms = entry.permissions`.
2. Build optional `DependencyPlan` from registry-only data when `entry.dependencies` non-empty (reuse `DependencyResolver.plan` with `DeclaredAddon(entry:)` + catalog map + installed versions). If resolver throws, surface error and abort (no download).
3. If `perms.isEmpty` && !(plan?.needsDisclosure ?? false) → install immediately (today’s path).
4. Else build `confirmInstallDisclosureUI` / single-permissions UI; `guard await InstallDisclosurePresenter.confirm(...)` else return.
5. Call `installer.install(..., confirmDependencies: { _ in true })` so the post-extract dep sheet does not double-prompt when already accepted. **Exception:** if post-extract plan has **additional** will-install deps not shown (registry omitted deps), installer must still disclose — pass:

```swift
confirmDependencies: { plan in
    if plan.needsDisclosure && !alreadyDisclosedDepIDs.isSuperset(of: Set(plan.dependencies.map(\.id))) {
        return await MainActor.run {
            /* present combined or dep-only via InstallDisclosurePresenter */
        }
    }
    return true
}
```

Simplest correct Now lock: **always** pass through installer `confirmDependencies` to `InstallDisclosurePresenter` with **permissions already shown omitted** only when App pre-confirmed the same dep ids; if App pre-confirmed full registry dep plan, pass `{ _ in true }`.

- [ ] **Step 2:** Delete NSAlert body from `DependencyInstallDisclosure` or make it call the presenter (prefer delete + use presenter only).

### 3.3 Browse Update — grew only

**Files:** Modify `BrowseCatalogViewModel.update`

- [ ] **Step 1:** Load installed permissions:

```swift
func installedPermissions(id: String) -> [AddonPermission] {
    let root = model.paths.addonsDir.appendingPathComponent(id)
    guard let m = try? ManifestLoader.load(from: root) else { return [] }
    return m.permissions
}
```

- [ ] **Step 2:** `let growth = PermissionsSet.grew(from: installedPermissions(id: entry.id), to: entry.permissions)`.
- [ ] **Step 3:** If `growth` non-empty → `confirmPermissionsGrewUI` via presenter; cancel → return.
- [ ] **Step 4:** Still run dep disclosure as in install (registry / installer backstop).
- [ ] **Step 5:** `cd shell && swift test` green. Phase 3 Done.

---

## Phase 4 — First-launch Continue

**Files:** Modify `shell/App/FirstRunWindow.swift` (and optionally `AppModel.completeFirstRun` if confirm must wrap installs).

- [ ] **Step 1:** On Continue (not Skip), before `onFinish(Array(session.selectedIDs))`:

1. Map selected ids → registry entries (skip unknown).
2. `unionExpand` from each entry’s permissions.
3. If expand non-empty → show confirm **in the first-launch window** (SwiftUI `.confirmationDialog` / sheet / inline `Confirm`-like block — **not** KeyablePanel). Use the same title/body strings as `confirmPermissionsMultiUI`.
4. On cancel → stay on step 2; on accept → `onFinish`.

Skip still installs nothing (no confirm).

- [ ] **Step 2:** Add `FirstRunPermissionsTests` if logic is extracted to Core+pure helper:

```swift
public enum FirstRunPermissions {
    public static func expand(entries: [RegistryEntry], selectedIDs: Set<String>)
        -> [(permission: AddonPermission, addonNames: [String])]
}
```

- [ ] **Step 3:** `cd shell && swift test` green. Phase 4 Done.

---

## Phase 5 — Keep-current bulk growths

**Files:** Modify `shell/App/KeepCurrentCoordinator.swift`, optionally `AddonBulkConfirmation.swift`.

- [ ] **Step 1:** When building bulk outdated list, compute growths per entry (`grew(from: installed, to: entry.permissions)`).
- [ ] **Step 2:** Extend bulk UI message (new helper or parameterize `confirmAddonBulkUI`):

```
{n} addons have updates. Update all?

Some updates newly need:
Accessibility
  • Window Layouts
Clipboard
  • Clip Tools
```

Omit the “newly need” block when every growth is empty (today’s message unchanged).

- [ ] **Step 3:** Cancel still downloads nothing. Per-entry installer dep confirms remain as in phase 3 wiring.
- [ ] **Step 4:** `cd shell && swift test` green. Phase 5 Done.

---

## Phase 6 — Card + detail surfaces

**Files:**
- Modify `shell/Sources/JugnuUI/AddonCardView.swift`
- Modify `shell/Sources/JugnuUI/AddonDetailView.swift`
- Modify `BrowseCatalogView` only if it must pass new props (prefer reading `entry.permissions` inside the views).

- [ ] **Step 1:** Card — after summary, if `PermissionsSet.needsLine(entry.permissions)` non-nil, show that string in caption secondary style.

- [ ] **Step 2:** Detail — after description (or after commands), section:

```
Permissions
Accessibility — Control other apps’ windows
Clipboard — Read or write the clipboard
```

Empty: `This addon does not need special permissions.`

- [ ] **Step 3:** No new XCTest required for SwiftUI layout; Core already covers strings. `swift test` green. Phase 6 Done.

---

## Phase 7 — Docs + smoke + ticket

**Files:**
- `docs/addon-manifest.md` — new “Permissions” section (closed ids, omit/`[]`, registry copy, unknown refuse)
- `PRIVACY.md` — one sentence: catalog install shows declared capabilities and confirms before download when any are listed
- `docs/architecture/shell-smoke.md` — paste spec §11 checklist under **Manual — permissions disclosure (0038)**
- `CHANGELOG.md` — Added line for 0038
- `docs/tickets.md` — 0038 remarks → Implemented when phases 1–7 green (Status **Done**, last updated today); leave 0054/0022 Not started / In progress as designed

- [ ] **Step 1:** Write the doc edits.
- [ ] **Step 2:** Full `cd shell && swift test` green.
- [ ] **Step 3:** Mark plan checkboxes done in this file as you go; Phase 7 Done = 0038 shippable in-tree (registry on `main` + GitHub zip republish remain release ops).

---

## Spec coverage (self-review)

| Spec Now requirement | Task |
|---|---|
| Closed ids + titles/reasons | 1.1 |
| Manifest + registry + validate | 1.2, 2.1–2.3 |
| Confirm if non-empty; empty fast path | 3.2 |
| Multi union + nested names | 1.1, 1.3, 4 |
| Grew-only update | 3.3 |
| Merge with dep disclosure | 1.3, 3.2 |
| Panel vs first-launch hosts | 3.1, 4 |
| Card one-liner + detail list | 6 |
| First-party table | 2.2 |
| Bulk keep-current growths | 5 |
| Smoke + PRIVACY + manifest docs | 7 |
| 0054 A/B, 0022 | Explicitly out of plan |

---

## Execution handoff

After this plan is accepted:

1. **Subagent-Driven (recommended)** — fresh subagent per phase/task, review between tasks  
2. **Inline Execution** — execute in this session with checkpoints  

Which approach?
