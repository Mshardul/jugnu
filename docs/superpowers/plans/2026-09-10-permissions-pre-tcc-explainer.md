# Permissions Pre-TCC Explainer (0054 A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 0054 A — Jugnu’s in-panel explainer immediately before any path that would trigger a macOS TCC prompt for a capability the addon declared, when the shell can tell the grant is not already allowed.

**Architecture:** JugnuCore owns copy builders + Privacy pane URL strings + “which declared ids are TCC.” App owns grant checks (Accessibility via `AXIsProcessTrusted()`, stubs for unused TCC ids), awaitable in-panel confirm (reuse `InstallDisclosurePresenter`), and a gate wrapped around every `runInvocation` `execute` / `followUp` spawn. Window-layouts helper stops prompting the OS itself so the shell explainer is truly first. Do not ship 0054 B, 0022, or Preferences rail chrome ([0064](../../tickets.md)).

**Tech Stack:** Swift / JugnuCore + App, ApplicationServices (`AXIsProcessTrusted`), existing `UIDescriptor` `.confirm` + `InstallDisclosurePresenter`, XCTest, window-layouts Swift helper.

**Spec:** [docs/architecture/2026-09-10-permissions-disclosure-design.md](../../architecture/2026-09-10-permissions-disclosure-design.md) — **§6 only** (Runtime pre-TCC explainer). Vocabulary from §3.1.

## Global Constraints

- **Git:** do not run git, do not branch, do not commit (`AGENTS.md`). Skip every “Commit” instinct; mark steps done after tests pass.
- **Every phase ships green.** End each phase with `cd shell && swift test` green before starting the next.
- **Honor §6 locks:** TCC ids only (`isTCC`); non-TCC never get this explainer; copy `{Addon name} needs {Permission title} to {shell-owned reason}.`; buttons **Open System Settings** / **Not now**; already granted → no sheet → run; Not now does not pretend granted; Open Settings deep-links then **ends this invoke** (user retries after granting — no poll loop, no spawn while denied).
- **Layering:** message builders + URL string helpers stay in **JugnuCore** (Foundation only). Grant checks + panel hosting + invoke wiring stay in **App**. No AppKit in Core.
- **Reuse:** same closed `AddonPermission` titles/reasons as 0038; same `InstallDisclosurePresenter.confirm` awaitable pattern. Do not invent a second confirm host.
- **Only first-party TCC customer today:** `jugnu.window-layouts` → `accessibility`. Other TCC ids get grant-check + deep-link stubs for future decls; do not add Info.plist camera/mic usage strings until an addon declares them.
- **Not this plan:** prefs rail ([0064](../../tickets.md)), detail Permissions tab polish (0054 B), TCC-reset storage (0022), shell Input Monitoring explainer (Later / 0022), glyphs (0051), sandboxing (0021).

---

## File map

| Path | Phase | Responsibility |
|---|---|---|
| `shell/Sources/JugnuCore/Permissions/PermissionsConfirmation.swift` | 1 | `confirmPreTCCExplainerUI` |
| `shell/Sources/JugnuCore/Permissions/TCCPrivacyURL.swift` | 1 | Privacy & Security deep-link URL strings per TCC id |
| `shell/Sources/JugnuCore/UserFacingError.swift` | 1 | Declined / awaiting-grant copy |
| `shell/Tests/JugnuCoreTests/PermissionsConfirmationTests.swift` | 1 | Explainer copy tests |
| `shell/Tests/JugnuCoreTests/TCCPrivacyURLTests.swift` | 1 | URL string tests |
| `shell/App/TCCGrantStatus.swift` | 2 | `isGranted(_:)` — Accessibility real; others conservative stubs |
| `shell/App/TCCExplainerGate.swift` | 2 | Walk declared TCC ids; present; open URL; throw on stop |
| `shell/App/JugnuApp.swift` | 3 | Wrap `execute` / `followUp` before `CommandInvoke.run` |
| `addons/jugnu.window-layouts/Sources/window-layouts/AX.swift` | 4 | Check without OS prompt |
| `docs/architecture/shell-smoke.md`, `CHANGELOG.md`, `docs/tickets.md` | 5 | Smoke + ticket remarks |

---

## Phase 1 — Core copy + Privacy URLs

**Ships:** `confirmPreTCCExplainerUI`, deep-link URL helpers, user-facing error cases, tests.

### 1.1 Explainer `UIDescriptor`

**Files:**
- Modify: `shell/Sources/JugnuCore/Permissions/PermissionsConfirmation.swift`
- Test: `shell/Tests/JugnuCoreTests/PermissionsConfirmationTests.swift`

- [x] **Step 1:** Write failing tests for exact title/message/labels.

```swift
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
```

Spec §6.2 body is one sentence; use addon **name** as the confirm title (short, panel-friendly). Message must include name + `displayTitle` + `reason` exactly in that template.

- [x] **Step 2:** Implement:

```swift
public func confirmPreTCCExplainerUI(
    addonName: String,
    permission: AddonPermission
) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: addonName,
        message: "\(addonName) needs \(permission.displayTitle) to \(permission.reason).",
        confirmLabel: "Open System Settings",
        cancelLabel: "Not now"
    )
}
```

- [x] **Step 3:** `cd shell && swift test --filter PermissionsConfirmationTests` green.

### 1.2 Privacy pane URL strings

**Files:**
- Create: `shell/Sources/JugnuCore/Permissions/TCCPrivacyURL.swift`
- Test: `shell/Tests/JugnuCoreTests/TCCPrivacyURLTests.swift`

- [x] **Step 1:** Failing tests — each TCC id returns a non-nil `URL` with known host/scheme; non-TCC returns `nil`.

```swift
public enum TCCPrivacyURL {
    /// Deep-link into System Settings → Privacy & Security when possible.
    public static func systemSettingsURL(for permission: AddonPermission) -> URL? {
        guard permission.isTCC else { return nil }
        let path: String
        switch permission {
        case .accessibility:
            path = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            path = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .camera:
            path = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            path = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .screenRecording:
            path = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .network, .clipboard, .background:
            return nil
        }
        return URL(string: path)
    }
}
```

On newer macOS, `x-apple.systempreferences:` may open Settings or fail soft — App still opens whatever URL we return; if open fails, still end the invoke with awaiting-grant copy (do not crash).

- [x] **Step 2:** Implement + tests green.

### 1.3 User-facing errors

**Files:**
- Modify: `shell/Sources/JugnuCore/UserFacingError.swift` (and a small `TCCGateError` enum — prefer in Core next to other gate errors, or in App if it must stay App-only; **lock: put `TCCGateError` in Core** so `UserFacingError.message` can switch on it without App→Core leak)

```swift
public enum TCCGateError: Error, Equatable {
    case declined(AddonPermission)
    case openedSettings(AddonPermission)
}

// UserFacingError.message:
// .declined(p) → "{Title} is required. Try again when you’re ready."
// .openedSettings(p) → "Turn on {Title} in System Settings, then try again."
```

Use `permission.displayTitle` for `{Title}`.

- [x] **Step 1:** Tests for both strings.
- [x] **Step 2:** Implement. `cd shell && swift test` green. Phase 1 Done.

---

## Phase 2 — Grant status + gate (App)

**Ships:** `TCCGrantStatus`, `TCCExplainerGate`, thin presenter reuse.

### 2.1 Grant checks

**Files:**
- Create: `shell/App/TCCGrantStatus.swift`

```swift
import ApplicationServices
import JugnuCore

enum TCCGrantStatus {
    /// Best-effort: true means “do not show explainer; run.”
    static func isGranted(_ permission: AddonPermission) -> Bool {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted()
        case .inputMonitoring:
            // No first-party addon declares this yet. Prefer “not granted”
            // so a future declaration still shows the explainer rather than
            // silently skipping. Refine when an addon needs it (CGPreflight…).
            return false
        case .camera, .microphone, .screenRecording:
            return false
        case .network, .clipboard, .background:
            return true
        }
    }
}
```

No XCTest required for Accessibility (needs TCC in CI). Optional pure tests only if you extract URL-open helpers.

### 2.2 Gate

**Files:**
- Create: `shell/App/TCCExplainerGate.swift`

```swift
import AppKit
import JugnuCore

@MainActor
enum TCCExplainerGate {
    /// For each declared TCC permission not already granted (display order):
    /// show explainer. Open Settings → throw `.openedSettings`. Not now → `.declined`.
    /// When all granted / none declared → return.
    static func ensureReady(
        addonName: String,
        permissions: [AddonPermission],
        shellHost: ShellHost,
        commandId: String
    ) async throws {
        let needed = PermissionsSet.sort(permissions.filter(\.isTCC))
        for permission in needed where !TCCGrantStatus.isGranted(permission) {
            let ui = confirmPreTCCExplainerUI(addonName: addonName, permission: permission)
            let openSettings = await InstallDisclosurePresenter.confirm(
                ui: ui,
                shellHost: shellHost,
                commandId: commandId
            )
            if openSettings {
                if let url = TCCPrivacyURL.systemSettingsURL(for: permission) {
                    NSWorkspace.shared.open(url)
                }
                throw TCCGateError.openedSettings(permission)
            }
            throw TCCGateError.declined(permission)
        }
    }
}
```

If `PermissionsSet.sort` is not public, use the same display-order sort already used elsewhere (`PermissionsSet` APIs from 0038) — do not reimplement sort ad hoc.

- [x] **Step 1:** Implement status + gate.
- [x] **Step 2:** `cd shell && swift test` green (App compiles with tests). Phase 2 Done.

---

## Phase 3 — Invoke wiring

**Ships:** every command invoke (palette + clock) gates before spawn.

### 3.1 Wrap execute / followUp in `JugnuApp`

**Files:**
- Modify: `shell/App/JugnuApp.swift` (`runCommand`, `runClockCommand`)

Do **not** put `ShellHost` into `AppModel.runInvocation` (layering). Wrap at the App call sites:

```swift
let invocation = try model.runInvocation(for: cmd)
let manifest = try ManifestLoader.load(from: cmd.addonRoot)
let gatedExecute: () async throws -> RunResponse = {
    try await TCCExplainerGate.ensureReady(
        addonName: manifest.name,
        permissions: manifest.permissions,
        shellHost: shellHost,
        commandId: cmd.qualifiedId
    )
    return try await invocation.execute()
}
let gatedFollowUp: (RunRequest) async throws -> RunResponse = { request in
    try await TCCExplainerGate.ensureReady(
        addonName: manifest.name,
        permissions: manifest.permissions,
        shellHost: shellHost,
        commandId: cmd.qualifiedId
    )
    return try await invocation.followUp(request)
}
await CommandInvoke.run(..., execute: gatedExecute, followUp: gatedFollowUp)
```

Same wrap in `runClockCommand`.

On `TCCGateError`, map via `UserFacingError.message` into `model.statusMessage` / panel error the same way other invoke failures surface today (mirror existing `catch` in `runCommand`). Do **not** spawn after Open Settings or Not now.

Daemon short-circuit in `runInvocation` never spawns — gate is harmless if somehow called; still only wrap paths that call `CommandInvoke.run`.

- [x] **Step 1:** Wire both call sites.
- [x] **Step 2:** `cd shell && swift test` green. Phase 3 Done.

---

## Phase 4 — Window-layouts: no OS prompt from helper

**Ships:** helper checks trust without prompting so §6.1 “before the API that triggers the system prompt” holds.

**Files:**
- Modify: `addons/jugnu.window-layouts/Sources/window-layouts/AX.swift`

```swift
static func ensureTrusted() throws {
    guard AXIsProcessTrusted() else {
        throw AXFailure.notTrusted
    }
}
```

Keep existing plain wire error in `main.swift` for `AXFailure.notTrusted` (`"Jugnu needs Accessibility to move windows."`) as backstop if the user grants to the wrong binary or trust lags — shell gate is the primary UX.

Rebuild the helper the same way this addon’s local build already does (`make` / package script used for window-layouts). Run any existing window-layouts unit tests if present.

- [x] **Step 1:** Change `ensureTrusted`.
- [x] **Step 2:** Rebuild helper; `cd shell && swift test` still green. Phase 4 Done.

---

## Phase 5 — Docs + ticket

**Files:**
- `docs/architecture/shell-smoke.md` — add **Manual — pre-TCC explainer (0054 A)**
- `CHANGELOG.md` — Added line for 0054 A
- `docs/tickets.md` — 0054 remarks: A shipped / B still open (prefs chrome [0064](../../tickets.md)); leave 0022 Not started

Smoke checklist:

```markdown
## Manual — pre-TCC explainer (0054 A)

- [ ] With Accessibility **off** for Jugnu: run a Window Layouts snap → in-panel explainer (“…needs Accessibility to…”); **Not now** → no OS TCC dialog, command does not complete successfully.
- [ ] Same, **Open System Settings** → Privacy Accessibility opens (or Settings opens); invoke ends with try-again copy; after granting and re-invoking → no explainer, snap works.
- [ ] With Accessibility **already on**: snap runs with no explainer.
- [ ] Invoke `jugnu.floating-note` / clip-tools: no pre-TCC explainer (non-TCC / none).
```

- [x] **Step 1:** Doc edits.
- [x] **Step 2:** Full `cd shell && swift test` green.
- [x] **Step 3:** Mark plan checkboxes done as you go. Phase 5 Done = 0054 A shippable in-tree.

---

## Spec coverage (self-review)

| Spec §6 requirement | Task |
|---|---|
| Before API that triggers TCC; only declared TCC | 2.2, 3, 4 |
| Non-TCC skip | 2.1 (`isTCC` filter), 3 |
| Copy + Open System Settings / Not now | 1.1 |
| Deep-link when possible | 1.2, 2.2 |
| Not now / no pretend grant | 2.2 throws `.declined` |
| Open Settings ends invoke; retry later | 2.2 `.openedSettings` + Phase 3 catch |
| Already granted → run | 2.1 + 2.2 loop skip |
| Reuse vocabulary §3.1 | `AddonPermission` |
| 0054 B / 0022 / prefs chrome | Explicitly out; prefs = [0064](../../tickets.md) |

---

## Execution handoff

After this plan is accepted:

1. **Subagent-Driven (recommended)** — fresh subagent per phase/task, review between tasks  
2. **Inline Execution** — execute in this session with checkpoints  

Which approach?
