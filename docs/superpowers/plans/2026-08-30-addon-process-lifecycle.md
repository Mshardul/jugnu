# Addon process lifecycle + crash recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shell the **owner** of addon process lifetime. One place knows what is running (`AddonProcessHost`), one set of kill rules per lifecycle class (`oneshot` / `job` / `daemon`), a spawn/wait split in `AddonRunner` so a running child can be cancelled on Esc, a crash-durable marker-file reaper that reaps escapees, and a crash-loop safe mode. Migrate the three addons that hand-roll background work.

**Architecture:** `AddonRunner` splits `run()` into `spawn() -> RunningInvocation` (returns once the child is live + its marker file written) and `waitForResponse()` (drains stdout, resolves the JSON object). `AddonProcessHost` (App target, `AppDelegate`-owned, mirrors `ClockHost`) holds a live entry per `(addon-id, command-id)` and is the real-time kill mechanism on every dismiss edge. The reaper reads `~/.local/share/jugnu/state/run/*.json` marker files on launch / wake / pre-quit and kills anything the host could not — a crashed shell's orphans, `disown`ed grandchildren, children spawned in the non-atomic spawn→register window. `daemon` commands never touch the host: the shell writes and owns a launchd plist, `com.jugnu.<id>.<cmd>` label, first-party-allowlisted only.

**Tech Stack:** Swift (`JugnuCore` structs + `JugnuUI` + App `@MainActor`), `api: 1` JSON protocol (additive only), XCTest with real `Process` + fixture misbehaving scripts, bash `scripts/validate-addon.sh`, `make`.

**Spec:** [docs/architecture/2026-08-30-addon-process-lifecycle-design.md](../../architecture/2026-08-30-addon-process-lifecycle-design.md) — build from §12.

## Global Constraints

- **Git:** do not run git, do not branch, do not commit. AGENTS.md hard rule. Work on the current checkout. Skip every "commit" instinct; mark a step done after tests pass. Leave the working tree for the user.
- **Every phase ships green and is independently shippable.** Each phase ends with `cd shell && swift test` green **and** `cd helpers/clock && swift test` green (when touched) **and** `scripts/validate-addon.sh` passing for every addon touched. Phase 1 is a **pure refactor** — the existing suite must still pass unchanged and nothing user-visible moves.
- **Honor the locked decisions in the spec's tables verbatim.** Do not relitigate `oneshot` default, per-`(addon-id, command-id)` keying, first-party `daemon` allowlist, marker-file scheme, 3-strike safe mode, `reuse` default, budget values. Where the spec says "named in `LatencyBudgets`", this plan names the constant.
- **Layering (conventions §Layering):** `RunningInvocation` and the runner split stay in `JugnuCore` (structs, `Sendable`, no AppKit). `AddonProcessHost`, the reaper, the crash-loop counter live in the **App** target (App owns all process lifetime — clock + addons, one layer). No new type in `JugnuUI` that spawns `Process`.
- **Known debt — do not clone** (conventions table): name new functions for the outcome (`popOrDismiss` / `dismiss` / `tearDownInFlight`), **not** `handleEsc` / `handleClickOutside`. New views in `JugnuUI`, not `App/`. Path-safe extraction only. `hide()` stays `orderOut`, never `panel = nil`.
- **Concurrency (conventions §Concurrency):** never `DispatchGroup.wait` on MainActor. Process wait, pipe drain, kill scheduling stay off MainActor. `AddonProcessHost` is `@MainActor`; its detached kill tasks are not. `[weak self]` / weak host in every monitor and `Task` closure in lifecycle code.
- **Hot path (conventions §Hot path):** the reaper runs on launch / wake / pre-quit only — never between key-down and first paint. No directory walk, no marker parse, no `kill(pid,0)` on the invoke path.
- **Errors (conventions §Types and errors):** every new `*Error` case that can reach the user gets a `UserFacingError.message(for:)` arm. Never surface "addon exited 1", a marker path, or a launchd label in a toast.
- **Compat (conventions §Compatibility):** every new manifest field is optional with a default reproducing today's behaviour. `lifecycle` omitted = `oneshot`. `api: 1` stays; `api: 2` is reserved for the `session` epic and is **not** touched here.
- **Not this plan:** the `session` class and its IPC (sibling epic, spec §11), `job` determinate-progress wire format (spec §10), full `daemon` authoring surface (spec §10), third-party `daemon` review flag (spec §10), `AddonInstaller.unzip()` zip-slip / atomic install (ticket 0058, spec §11), startup watchdog (spec §10 — a phase-4 *note*, not built). Do not design 0058 or 0059.

## Fixture: the misbehaving addon (shared test asset, Phase 1 deliverable)

Created once in Phase 1, reused by every later phase. Location: `shell/Tests/Fixtures/misbehaving/` (plain executable scripts, `chmod +x`, no addon manifest needed — the runner-split tests call `run(addonRoot:entrypoint:request:timeout:)` directly with a synthetic `Entrypoint(kind: "exec", path:)`).

| Script | Behaviour | Exercises |
|---|---|---|
| `fast-exit` | prints one valid `{"ok":true,"message":"done"}` and exits 0 immediately | happy path, marker delete on exit |
| `sleep-forever` | prints nothing, `sleep 86400` | cancel → SIGTERM within `killGrace`; `jobHandshakeWindow` failed-launch; reaper orphan |
| `sigterm-ignorer` | `trap '' TERM`, prints one heartbeat, then `sleep 86400` | SIGTERM ignored → SIGKILL escalation after `killGrace` |
| `stops-heartbeating` | prints a `\n` every 1 s for 5 s, then `sleep 86400` silently | `jobHeartbeatWindow` watchdog → SIGKILL + error |
| `slow-oneshot` | `sleep 30`, then prints a valid object | `oneshotHardCeiling` clamp |
| `disowns-child` | spawns `( sleep 86400 ) & disown`, prints a valid object, exits 0 | reaper catches the leaked grandchild; `validate-addon.sh` `disown` warning |

A tiny `FixtureScripts` helper (App tests) resolves `Bundle.module` / a test-resource path to these; keep it in one place.

---

## File map

| Path | Phase | Responsibility |
|---|---|---|
| `shell/Sources/JugnuCore/AddonRunner.swift` | 1, 3, 4 | `spawn()` / `waitForResponse()` / `terminate()`; marker write+delete; `job` watchdog; env stamping |
| `shell/Sources/JugnuCore/RunningInvocation.swift` | 1 | new Core struct — live `Process` + pipes + async response |
| `shell/Sources/JugnuCore/Latency/InvokeTrace.swift` | 1 | 5 new `LatencyBudgets` constants |
| `shell/Sources/JugnuCore/Lifecycle/LifecycleEvent.swift` | 1 | `LifecycleEvent` record + `lifecycle.log` capped writer |
| `shell/Sources/JugnuCore/Lifecycle/RunMarker.swift` | 1, 4 | marker file model + read/write/enumerate under `state/run/` |
| `shell/Sources/JugnuCore/Paths.swift` | 1, 4 | `stateRunDir`, `lifecycleLogFile`, `crashCounterFile` |
| `shell/Sources/JugnuCore/Manifest/AddonManifest.swift` | 3 | `lifecycle`, `on_reinvoke`, `timeout`, command-level `daemon` block parsing |
| `shell/App/AddonProcessHost.swift` | 1, 2, 3 | App-target host, `AppDelegate`-owned, `(addon-id, command-id)` keyed |
| `shell/App/AddonReaper.swift` | 4 | marker-dir reaper, normal + degraded modes |
| `shell/App/LaunchGuard.swift` | 4 | crash-loop counter + safe-mode decision |
| `shell/App/DaemonAgents.swift` | 3, 5 | shell-generated plist author + `launchctl` bootstrap/bootout |
| `shell/App/AppModel.swift` | 1, 2, 3 | `runInvocation` rewired to `spawn()` + host register/deregister |
| `shell/App/JugnuApp.swift` | 2, 4 | dismiss-edge kills, quit `killAll`, sleep/wake, reaper triggers, safe-mode boot |
| `shell/Sources/JugnuUI/ShellHost.swift` | 2 | dismiss detached `card` / `note` panels on quit + sleep |
| `shell/Sources/JugnuUI/PaletteView.swift`, `BrowseCatalogView.swift` | 2 | view-owned `Task` cancel-on-disappear |
| `scripts/validate-addon.sh` | 3 | `lifecycle` enum, `daemon` first-party gate, `timeout` clamp, `disown` warning |
| `addons/pomodoro/`, `addons/keep-awake/`, `addons/clipboard-history/` | 5 | migrate off hand-rolled background work |
| `docs/addon-manifest.md` | 3 | document new fields + 3-class table + reserved `session` |
| `docs/architecture/2026-08-22-addon-ui-speed-design.md` | 3 | §7 context-invoke `reuse`-on-collision cross-ref |
| `docs/architecture/shell-smoke.md` | 4 | manual sleep/wake, reaper-after-crash, `make stop`, safe-mode, heartbeat checks |
| `Makefile` | 2 | `make stop` = real SIGTERM quit; new `make clean-agents` |
| `docs/tickets.md`, `docs/backlog.md`, `CHANGELOG.md` | 1, 5 | ticket 0057 rows, changelog |

---

## Phase 1 — runner seam + host + marker files (no behaviour change)

**Ships green; nothing user-visible changes. The existing test suite must still pass.**

### 1.1 `LatencyBudgets` — add the five named budgets

`shell/Sources/JugnuCore/Latency/InvokeTrace.swift`, in `enum LatencyBudgets`:

| Constant | Value | Meaning (spec §2) |
|---|---|---|
| `oneshotHardCeilingMs` | `10_000` | absolute clamp on a `oneshot` invoke |
| `jobHandshakeWindowMs` | `10_000` | first `job` output must land within this of spawn |
| `jobHeartbeatWindowMs` | `10_000` | max silence between `job` heartbeats |
| `killGraceMs` | `500` | SIGTERM→SIGKILL grace on an edge kill |
| `replaceDeathCeilingMs` | `2_000` | max wait for a `replace`d child to die before giving up |

Keep the existing `Int`-milliseconds style. The 0.8 s default runner timeout (`AddonRunner.timeoutSeconds`) stays as the `oneshot` *target*; `oneshotHardCeilingMs` is the hard kill.

### 1.2 `RunningInvocation` — new Core struct

Create `shell/Sources/JugnuCore/RunningInvocation.swift`:

- `public struct RunningInvocation` (or `final class` if it must hold mutable pipe-drain state — pick struct if the closures can capture; the spec calls it "a Core type", shape `{ process, waitForResponse() async throws -> RunResponse, terminate() }`).
- Holds the live `Process`, the three `Pipe`s, and the marker file URL.
- `func waitForResponse() async throws -> RunResponse` — drains stdout to completion off MainActor, decodes the one JSON object (reuse `RunJSON.decodeResponse`), applies the same `terminationStatus != 0` → stderr-as-error fallback the current `run()` has.
- `func terminate()` — SIGTERM, wait `killGraceMs` off MainActor, SIGKILL if `isRunning`. Idempotent.
- The child's `terminationHandler` deletes the marker file (best-effort `try?` — conventions allow `try?` for state/cache writes).

### 1.3 `AddonRunner.spawn(...)`

`shell/Sources/JugnuCore/AddonRunner.swift`:

- New `public func spawn(manifest:addonRoot:commandId:args:context:timeout:paths:) throws -> RunningInvocation` and a lower-level `spawn(addonRoot:entrypoint:request:extraEnvironment:) throws -> RunningInvocation`.
- Builds the `Process` exactly as `run()` does today (same `exec` / `jxa` / `osascript` switch, same cwd, same helper env merge), calls `process.run()`, writes stdin, closes it.
- **Before returning:** write `~/.local/share/jugnu/state/run/<pid>.json` via `RunMarker` (1.4).
- Returns a `RunningInvocation` wrapping the live process + pipes + marker URL.
- **Keep the existing `run()`** as a thin wrapper: `spawn()` + a bounded `waitForResponse()` under the passed timeout, `terminate()` on timeout, throw `AddonRunnerError.timeout` — so every current call site and test is behaviour-identical. (`run()` is deleted only if/when no caller remains; Phase 1 keeps it.)
- `AddonRunnerError` gains no user-facing case here; `terminate`/marker failures are swallowed.

### 1.4 `RunMarker` + `Paths`

`shell/Sources/JugnuCore/Paths.swift` — add:
```swift
public var stateRunDir: URL { stateDir.appendingPathComponent("run") }
public var lifecycleLogFile: URL { stateDir.appendingPathComponent("lifecycle.log") }
public var crashCounterFile: URL { stateDir.appendingPathComponent("launch-attempts") }
```
(`stateDir` already exists — `~/.local/share/jugnu/state`.)

`shell/Sources/JugnuCore/Lifecycle/RunMarker.swift`:
- `public struct RunMarker: Codable, Equatable` — `origin: String` (`"<addon-id>:<command-id>:<invoke-uuid>"`), `lifecycleClass: String` (`"class"` JSON key via `CodingKeys` — `class` is a Swift keyword), `shellPID: Int32`, `shellStartTS: Double`, `spawnedAt: Double`.
- `static func write(_:to dir:) throws` — atomic (temp + rename), filename `<pid>.json`.
- `static func delete(pid:in dir:)` — best-effort.
- `static func enumerate(in dir:) -> [(pid: Int32, marker: RunMarker?)]` — tolerates missing dir, garbage files, unreadable entries (each maps to `marker: nil`, never throws). Used by the reaper in Phase 4.
- Shell start-ts source: `ProcessInfo` boot-relative is wrong across reboots — use the process's own start time. A small helper `ShellIdentity.current()` → `(pid: getpid(), startTS: <kinfo_proc p_starttime via sysctl>)`, App-side is cleanest but the value must be passed *into* `spawn()` (Core takes it as a param, does not read it). Put `ShellIdentity` in App; `spawn()` gains `shellIdentity: (pid: Int32, startTS: Double)`.

### 1.5 `LifecycleEvent` + `lifecycle.log`

`shell/Sources/JugnuCore/Lifecycle/LifecycleEvent.swift`:
- `public struct LifecycleEvent: Codable` — `event: String` (`"kill"` / `"reap"` / `"safe_mode"`), plus optional `origin`, `reason`, `strikeCount`, `ts`.
- `public struct LifecycleLog` — `init(fileURL:now:)`, `func record(_:)` appends one JSON line, caps the file at ~200 lines (read-tail-rewrite, best-effort `try?`).
- **Reap and safe-mode events write in all build configs.** Every other event (edge kill, `replace`, quit kill) is `#if DEBUG` only, matching `InvokeTrace`'s trace-print ceiling. Wire that gate here so Phase 2/3 callers just call `record`.

### 1.6 `AddonProcessHost` (App target)

Create `shell/App/AddonProcessHost.swift`:
- `@MainActor final class AddonProcessHost` — mirrors `ClockHost`: `AppDelegate`-held, `start()` / `stop()` shape (here `stop()` = `killAll()`).
- Keyed by `struct CommandKey: Hashable { let addonID: String; let commandID: String }`. Value: `[Entry]` (normally 0–1; a `oneshot` re-invoke can briefly make 2).
- `struct Entry { let invocation: RunningInvocation; let invocationTask: Task<Void, Never>?; let lifecycleClass: LifecycleClass; let startedAt: Date; let invokeUUID: UUID; let markerPath: URL; var phase: Phase }` where `Phase` is `.live` / `.dying`.
- API: `register(key:entry:)`, `deregister(key:invokeUUID:)`, `killTracked(key:)`, `killAll()`, `hasTracked(key:) -> Bool`, `tracked() -> [Entry]`.
- `register` is called immediately after `spawn()` returns, **before** the response is awaited. `deregister` is called from the `terminationHandler` (hop to MainActor).
- `killTracked` — fire-and-forget: mark entries `.dying`, `invocation.terminate()` on a detached task, return now. `terminationHandler` does the real removal.
- `killAll()` — one SIGTERM broadcast, one shared `killGraceMs`, one SIGKILL broadcast, return. Does **not** await individual `terminationHandler`s (`applicationWillTerminate` has a ~5 s OS deadline).
- **Phase 1 scope:** the single-process guard and `on_reinvoke` are stubbed — `register` always registers, no class-based blocking. `oneshot`-only. `LifecycleClass` enum exists with just `.oneshot` (the `job` / `daemon` arms land in Phase 3; the enum is `public` and open per spec).

### 1.7 `AppModel.runInvocation` rewired

`shell/App/AppModel.swift` (currently lines ~118–150, two `Task.detached { runner.run(...) }.value` closures):
- Both the initial-invoke `execute` closure and the follow-up closure now: `let inv = try runner.spawn(...)`; `host.register(key:, entry:)`; `let response = try await inv.waitForResponse()` bounded by `oneshotHardCeilingMs`; the awaiting work is a structured `Task` the invoke flow **owns** (so Phase 2 can cancel it), not `Task.detached`.
- `terminationHandler` on the `RunningInvocation`'s process calls `host.deregister` + marker delete (marker delete already in `RunningInvocation`; host deregister is the addition).
- No `Task.detached`. Follow-up spawns are `oneshot` by lifetime and tracked for their brief life.
- Behaviour from the user's POV is identical — same timeout feel, same toast, same follow-up.

### 1.8 Tests

**Core** (`shell/Tests/JugnuCoreTests/`, real processes + fixture scripts):
- `AddonRunnerSpawnTests`:
  - `test_spawn_returnsLiveHandle_processIsRunning` (`fast-exit` — race: assert before it exits, or use `sleep-forever`).
  - `test_waitForResponse_resolvesAndDrainsStdout` (`fast-exit` → `.ok == true`, message `"done"`).
  - `test_terminate_killsChildWithinKillGrace` (`sleep-forever` → `terminate()` → process dead, elapsed < `killGraceMs` + slack).
  - `test_terminate_sigtermIgnorer_escalatesToSIGKILL` (`sigterm-ignorer` → dead after ~`killGraceMs`).
  - `test_spawn_writesMarker_terminationDeletesIt` (temp `JugnuPaths(home:)`; marker file exists after `spawn`, gone after exit).
  - `test_run_wrapper_behaviourUnchanged` (the existing runner-fixture tests still green — do not modify them).
- `RunMarkerTests`: round-trip codec incl. the `class` → `lifecycleClass` key; `enumerate` tolerates missing dir / garbage file / unreadable entry.
- `LifecycleLogTests`: appends a line; caps at ~200; corrupt existing file → still writes.

**App** (`shell/Tests/JugnuUITests/` or a new `JugnuAppTests` target if none exists — check `Package.swift`; the spec's App tests need `@testable import`):
- `AddonProcessHostTests`: `register` then `hasTracked` true; `deregister` by `invokeUUID` → false; two entries for one key coexist; `killAll` marks all `.dying` and returns without awaiting; per-`CommandKey` isolation (key A untouched when key B killed).

**Verification:** `cd shell && swift test` — green, count ≥ prior. `scripts/validate-addon.sh` unaffected (no manifest change). Nothing user-visible.

### Review checkpoint — Phase 1

- [ ] `spawn()` / `RunningInvocation` in `JugnuCore`, structs, no AppKit import. `AddonProcessHost` in App, `@MainActor`, `AppDelegate`-owned like `ClockHost`.
- [ ] `run()` wrapper keeps every existing call site and test behaviour-identical; no test file edited to make it pass.
- [ ] Marker written before `spawn()` returns; deleted in `terminationHandler`; `enumerate` never throws.
- [ ] No `Task.detached` left in `runInvocation`; the awaiting task is owned by the invoke flow.
- [ ] `LatencyBudgets` has the 5 constants with the spec's exact values.
- [ ] Reap/safe-mode log path compiles in release; other events `#if DEBUG`.
- [ ] Conventions: no `handleEsc`-style names, no `///`, no new singleton, no `DispatchGroup.wait` on MainActor.
- [ ] `cd shell && swift test` green.

---

## Phase 2 — kill on every edge

Now that a running child is cancellable, wire every dismiss / quit / sleep edge to actually kill it. Still `oneshot`-only (no class model yet) — `killTracked` / `killAll` operate on all tracked entries.

### 2.1 Dismiss edges

`shell/App/JugnuApp.swift` — the methods currently named `handleEsc` (~136), `handleClickOutside` (~152), and the stack-pop path:
- **Rename** as part of this work (known-debt cleanup, ticket 0013): `handleEsc` → `popOrDismiss`, `handleClickOutside` → `dismissFromClickOutside`. Update the `armClickOutsideDismiss` / `setOnCancel` / `onCancelFollowUp` call sites.
- Each, before dismissing the panel: cancel the owned invoke `Task` (→ `RunningInvocation.terminate()` via structured cancellation) **and** `host.killTracked(key:)` for the in-flight command's key. Fire-and-forget — the panel dismisses immediately, no await (conventions: teardown never makes the user wait).
- `popTop` (leaving one stack level into another) kills the level being left.

### 2.2 Quit

`applicationWillTerminate` (~87, currently only `clockHost?.stop()`):
- Add `host.killAll()` after `clockHost?.stop()`.
- Phase 2 has no `job` yet, so the "prompt if a `job` is in flight" branch is a **TODO stub** wired in Phase 3 — leave a `docs/tickets.md` note, not a code `TODO` (conventions).
- The quit **menu item** routes through the same path.
- `killAll()` is parallel + bounded (built in 1.6) — one SIGTERM broadcast, one grace, one SIGKILL broadcast, no per-child await.

### 2.3 Sleep / wake

- `NSWorkspace.willSleepNotification` observer in `AppDelegate` → `host.killAll()` (tears down every mid-flight `oneshot`; Phase 3 narrows this to "kill `job` + mid-flight `oneshot`, leave `daemon`" — but `daemon` is never in the host, so `killAll()` is already correct) + tell `ShellHost` to dismiss detached `card` / `note` panels.
- `NSWorkspace.didWakeNotification` observer → **reaper trigger stub** (Phase 4 fills the reaper; Phase 2 just registers the observer and logs).
- `[weak self]` on both observers; remove them in `applicationWillTerminate`.

### 2.4 `ShellHost` — detached panel teardown

`shell/Sources/JugnuUI/ShellHost.swift`:
- `func dismissDetachedPanels()` — `orderOut` + release the `card` / `note` `NSPanel`s the host tracks (the process that produced them has already exited; this is view teardown, not process teardown).
- Called from the quit path and the sleep observer.

### 2.5 View-owned `Task` cancel-on-disappear

- `PaletteView` search-debounce `Task` and `BrowseCatalogView` install `Task` → `.task {}` modifier (or `.onDisappear` cancel of a stored handle) so a navigated-away / dismissed panel writes no stale result.
- `NSEvent` monitor + `Task` closure hygiene in the touched lifecycle code: `[weak self]`, explicit teardown.

### 2.6 Palette invoke debounce

- Reuse the `PaletteView` search-debounce pattern (~100 ms, conventions §Hot path) for repeat-invokes of the same command so a mashing user coalesces into one spawn.

### 2.7 `make stop` + `make clean-agents`

`Makefile`:
- `make stop` → send **SIGTERM** to the `Jugnu` process, bounded wait, then SIGKILL — so `applicationWillTerminate` fires and `host.killAll()` runs. **Not** `kill -9` (that skips the quit path). Daemon agents are left running (they survive quit by design; none exist until Phase 3/5).
- New `make clean-agents` → explicit `launchctl bootout gui/$(id -u)/com.jugnu.*` for a dev clean slate.

### 2.8 Tests

**App:**
- `test_dismiss_leavesNoTrackedProcess` — **the ticket-0014 canary.** Spawn a `sleep-forever` fixture via the real invoke path, trigger `popOrDismiss`, assert `host.tracked()` drains and the child pid is dead within `killGraceMs` + slack. Covers `oneshot`.
- `test_quit_killAll_isParallelAndBounded` — register N `sleep-forever` entries, call `killAll()`, assert it returns in ≤ `killGraceMs` + slack (not N × grace) and all children die.
- `test_sleep_tearsDownMidFlightInvocation` — willSleep handler → tracked drains.
- `test_clickOutside_and_esc_bothCancel` — both renamed methods hit `killTracked`.

**JugnuUI:** `PaletteView` / `BrowseCatalogView` `Task`-cancel-on-disappear (stack/preset-level, per conventions "no live NSPanel in unit tests").

**Verification:** `cd shell && swift test` green. Manual: `make run`, invoke a slow command, hit Esc, `pgrep -f <fixture>` → nothing. `make stop` while a command runs → clean exit.

### Review checkpoint — Phase 2

- [ ] `handleEsc` / `handleClickOutside` renamed to outcome names; all call sites updated; no lingering old name.
- [ ] Every dismiss edge (Esc, click-outside, pop) cancels the owned `Task` **and** `killTracked` — fire-and-forget, panel dismisses with no await.
- [ ] `applicationWillTerminate` + quit menu → `killAll()`; `job`-prompt is a ticket note, not a code TODO.
- [ ] willSleep → `killAll()` + `dismissDetachedPanels()`; didWake observer registered (reaper stub).
- [ ] View `Task`s cancel on disappear; observers `[weak self]` + removed on terminate.
- [ ] `make stop` = SIGTERM (not `kill -9`); `make clean-agents` added.
- [ ] `test_dismiss_leavesNoTrackedProcess` present and green.
- [ ] `cd shell && swift test` green; `scripts/validate-addon.sh` unaffected.

---

## Phase 3 — class model (`oneshot` / `job` / `daemon`)

### 3.1 Manifest parsing

`shell/Sources/JugnuCore/Manifest/AddonManifest.swift`:
- `enum LifecycleClass: String, Codable { case oneshot, job, daemon }` — decoding `"session"` throws a typed error whose `UserFacingError` copy is *"This addon needs a newer version of Jugnu (session addons are not yet supported)."*
- Command model gains `lifecycle: LifecycleClass?` (nil → inherit), `onReinvoke: OnReinvoke?` (`enum { case reuse, replace }`, default `.reuse`), `timeout: TimeInterval?`, `daemon: DaemonBlock?`.
- Addon-root gains `lifecycle: LifecycleClass?` as the default for all its commands.
- `struct DaemonBlock: Codable, Equatable { let program: String; let args: [String]?; let keepAlive: Bool? }` — command-level only. `CodingKeys`: `keep_alive`.
- Resolution: effective class = command `lifecycle` ?? addon-root `lifecycle` ?? `.oneshot`.
- `timeout` is read but the runner clamps it to `oneshotHardCeilingMs` (3.3).

Tests: `AddonManifestLifecycleTests` — omitted → `.oneshot`; command overrides root; `"session"` → the typed error; `daemon` block parses; `on_reinvoke` default `.reuse`.

### 3.2 `validate-addon.sh`

`scripts/validate-addon.sh` — add after the existing entrypoint checks:
- `lifecycle` (root or any command) must be one of `oneshot` / `job` / `daemon`; `session` → fail with *"session addons are not yet supported"*.
- `lifecycle: daemon` on any command → the addon `id` must be in a hardcoded first-party allowlist (`keep-awake`, `clipboard-history` — a `FIRST_PARTY_DAEMON_IDS` bash array at the top of the script). Otherwise fail: *"daemon lifecycle is first-party only"*.
- Every command with `lifecycle: daemon` must have its own `daemon:` block with a `program:` — else fail.
- Any `timeout:` value > 10 (seconds) → fail: *"timeout must be ≤ oneshotHardCeiling (10s)"*.
- **Warn** (non-fatal, stderr, exit 0) on `disown`, `nohup`, or a trailing ` &` in the entrypoint file — *"background work belongs in a daemon or the clock helper"*. Lint nudge, not a boundary.

Test: extend whatever drives `validate-addon.sh` in CI (a shell test or a Swift wrapper) with a fixture addon dir per case. If none exists, add `shell/Tests/validate-addon-cases/` + a `test_validateAddon_*` runner.

### 3.3 `job` handling in `AddonRunner` + `AddonProcessHost`

- `AddonRunner`: `waitForResponse()` gains a mode param (or a sibling `waitForJobResponse()`):
  - first output must arrive within `jobHandshakeWindowMs` of spawn → else SIGKILL + `AddonRunnerError.jobHandshakeTimeout` (user copy: *"The addon didn't start in time."*).
  - a heartbeat watchdog resets on **every line** of stdout; silence past `jobHeartbeatWindowMs` → SIGKILL + `AddonRunnerError.jobUnresponsive` (*"The addon stopped responding."*).
  - **no wall-clock cap** — a `job` is expected long.
- `AddonProcessHost`: `LifecycleClass` now has `.job`. The single-process guard activates: on a `.job` spawn, if a live `.job` entry exists for the `CommandKey`, apply `on_reinvoke` (3.4) instead of spawning. `.oneshot` never blocks (a second `oneshot` just spawns).

### 3.4 `on_reinvoke`

`AddonProcessHost`:
- `.job` + `.reuse`: block the second spawn; surface the running job's progress UI (bring the indeterminate spinner + Cancel forward).
- `.job` + `.replace`: **SIGKILL immediately** (no polite grace — the user asked). Wait ≤ `replaceDeathCeilingMs` for confirmed death via `terminationHandler`; on confirm, spawn fresh; if still not dead, surface *"Previous run is still stopping — try again in a moment"* and **do not spawn**. Never two concurrent children for one command.
- Re-invoke during `.dying`: treat the `.dying` entry as live for the decision. `.reuse` waits for the slot; a further `.replace` before the slot frees updates the pending request (last-request-wins, no queue). Panel shows a "restarting…" micro-state.
- **Constraint recorded for the future context-aware design:** a context-triggered / programmatic invoke that collides with a running instance behaves as `.reuse` **regardless of the field**. Add this as a `//` why on the collision branch and cross-reference it in the UI-speed spec (3.8).

### 3.5 `job` UI

- Shared indeterminate-progress + **Cancel** chrome (the UI-host v1 "multi-second work with cancel" pattern — reuse it, do not invent). Cancel → `host.killTracked`.
- After ~60 s the label softens to *"Still working — longer than usual"*. No wall-clock cap.
- Heartbeat frames are **liveness only** — a bare `\n` or any output resets the watchdog. Determinate progress (%, steps) is deferred (spec §10) and is explicitly **not** built here.

### 3.6 `daemon` — shell-generated launchd agents

Create `shell/App/DaemonAgents.swift`:
- `struct DaemonAgents` — `bootstrap(addonID:commandID:block:addonRoot:paths:)`, `bootout(addonID:commandID:)`.
- **First-party trust gate:** a hardcoded `firstPartyDaemonIDs: Set<String>` (`["keep-awake", "clipboard-history"]`). `bootstrap` refuses (and load refuses) any other id.
- Plist author — the **shell** writes `~/Library/LaunchAgents/com.jugnu.<addon-id>.<command-id>.plist`:
  - `Label` = `com.jugnu.<addon-id>.<command-id>`.
  - `ProgramArguments` = [`program` resolved relative to the addon root] + `args`.
  - `RunAtLoad` / `KeepAlive` from `keep_alive` (default `true`).
  - `StandardOutPath` / `StandardErrorPath` under `~/.local/share/jugnu/state/<addon-id>/`.
  - `EnvironmentVariables` = `JUGNU_ORIGIN` (`<addon-id>:<command-id>`) + `JUGNU_SHELL_START_TS` (the spawning shell's start-ts, §6 groundwork — used by the reaper's degraded attribution).
- Bootstrap on **enable** (and first-install-with-enable, including first-run onboarding): `launchctl bootstrap gui/<uid> <plist>`.
- Teardown on **disable / uninstall**: `launchctl bootout` + remove the plist. `cleanup.launchd` is auto-populated from the `daemon` block.
- A `daemon` **never** enters `AddonProcessHost` and writes **no marker** (launchd-owned).
- Reject an addon-shipped `.plist` at validate time (the manifest is the trust boundary; the shell authors the plist).

### 3.7 Open-panel disable alert (ticket 0032 slice)

- Before `lifecycle.setEnabled(id:, false)` / uninstall: if `AddonProcessHost.hasTracked` for any of that addon's commands, show an accept / reject alert (an AppKit `NSAlert` from App — **not** a SwiftUI `.alert` in the panel, conventions). Accept → `killTracked` + proceed. Reject → cancel. (0032's uninstall-specific concerns stay on 0032.)

### 3.8 Docs

- `docs/addon-manifest.md`: document `lifecycle`, `on_reinvoke`, `timeout`, `daemon` block; the 3-class table (spec §2); the reserved `session` value and its rejection message.
- `docs/architecture/2026-08-22-addon-ui-speed-design.md` §7: add the context-invoke `reuse`-on-collision cross-reference (so a future context designer sees the constraint).

### 3.9 Tests

- `AddonManifestLifecycleTests` (3.1).
- `validate-addon` cases (3.2).
- `JobWatchdogTests` (Core, fixtures): `stops-heartbeating` → SIGKILL + `jobUnresponsive` within `jobHeartbeatWindowMs` + slack; `sleep-forever` → `jobHandshakeTimeout` within `jobHandshakeWindowMs`; a well-behaved heartbeating fixture runs past the window without a kill.
- `OnReinvokeTests` (App): `.job` + `.reuse` blocks the 2nd spawn, brings 1 entry forward; `.job` + `.replace` SIGKILLs then spawns; `.replace` with an un-dying child → "still stopping", no 2nd spawn; `.oneshot` never blocks.
- `DaemonAgentsTests` (App, temp `LaunchAgents` dir + a fake `launchctl`): plist contents match the declared block; non-allowlisted id refused; `bootout` removes the plist; `cleanup.launchd` auto-populated.
- `test_disableWhileTracked_promptsAndKills` (App).

**Verification:** `cd shell && swift test` green; `scripts/validate-addon.sh` green for all existing addons (none declare `lifecycle` yet → all resolve `.oneshot`, unchanged).

### Review checkpoint — Phase 3

- [ ] `LifecycleClass` enum open; `session` rejected at load **and** in `validate-addon.sh` with the spec's message.
- [ ] Effective class = command ?? root ?? `.oneshot`. `on_reinvoke` default `.reuse`, read for `.job` only.
- [ ] `timeout` clamped to `oneshotHardCeilingMs` in the runner, rejected > 10s at validate time.
- [ ] `job`: `jobHandshakeWindowMs` first-output check + `jobHeartbeatWindowMs` watchdog + SIGKILL, **no** wall-clock cap.
- [ ] Single-process guard is per-`CommandKey`, `.job` only; `.oneshot` never blocks; `daemon` never in the host, no marker.
- [ ] `.replace` = immediate SIGKILL, wait ≤ `replaceDeathCeilingMs`, spawn-or-"still stopping" — never two concurrent children.
- [ ] `daemon`: shell authors the plist, first-party allowlist enforced two places, bootstrap on enable / bootout on disable, `cleanup.launchd` auto-populated, addon-shipped `.plist` rejected.
- [ ] Disable-while-tracked uses `NSAlert` from App, not a panel `.alert`.
- [ ] Context-invoke `reuse`-on-collision constraint in code (`//` why) + UI-speed spec §7.
- [ ] `docs/addon-manifest.md` documents every new field + the 3-class table.
- [ ] `cd shell && swift test` + `validate-addon.sh` green.

---

## Phase 4 — reaper + crash-loop (**the riskiest phase**)

The reaper is the piece most likely to misfire — a wrong kill authority kills a live child, a wrong PID-reuse check spares a real orphan or kills an innocent process. sleep/wake/launchctl **cannot be CI-tested**; the manual steps in `shell-smoke.md` are load-bearing, not optional.

### 4.1 Env + start-ts stamping

- `AddonRunner.spawn()`: stamp `JUGNU_ORIGIN` (`<addon-id>:<command-id>:<invoke-uuid>`) + `JUGNU_SHELL_START_TS` on **every** spawn's environment. The reaper does **not** depend on reading these back (macOS restricts `ps -E`); they are a free `ps` / Activity Monitor debugging tag and a degraded-mode attribution hint.
- The `clock` helper (`helpers/clock`, `ClockHost.start()`): write one marker `state/run/<pid>.json` with `origin: "jugnu:clock"` on `start()`, delete on `stop()`. `ClockHost` is App-side — pass it the marker dir + shell identity.
- Generated `daemon` plists already carry these as `EnvironmentVariables` (3.6).

### 4.2 `AddonReaper` (App)

Create `shell/App/AddonReaper.swift`:
- `func reap(mode: Mode)` — `Mode` is `.normal` / `.degraded`.
- Reads `RunMarker.enumerate(in: paths.stateRunDir)`.
- **Normal-mode kill authority** — a marker's target pid is an orphan to kill **iff all** of:
  1. `kill(pid, 0) == 0` (pid is alive), **and**
  2. the process carries a `JUGNU_ORIGIN`-consistent identity (best-effort; the marker is the authority — do not skip a kill just because the env read failed), **and**
  3. **no** live process matches *both* `marker.shellPID` **and** `marker.shellStartTS` with comm name `Jugnu` (PID reuse cannot spoof the start-time — this is the cross-check that makes it safe), **and**
  4. it is not a live `Entry` the `AddonProcessHost` currently owns.
- On a kill: SIGTERM, `killGraceMs`, SIGKILL if alive. Write a `LifecycleEvent(event: "reap", origin:, reason:, ts:)` to `lifecycle.log` (**all build configs**).
- **Degraded mode** (safe mode — manifests are not trusted, §8): kill every marker's pid that is alive and whose `(shellPID, shellStartTS)` has no matching live `Jugnu` shell — **without** a manifest class lookup. Coarser, still safe. A genuinely-orphaned `daemon`-spawned child has no marker → degraded mode leans on the §8 blanket `com.jugnu.*` bootout for those.
- **Stale-marker hygiene:** a marker whose pid is dead, or reused by a non-`Jugnu` process, is deleted on sight.
- **Cost:** read a small dir + a few `kill(pid, 0)` / comm-name checks. Sub-ms to low-ms. Only ever on launch / wake / pre-quit — never the invoke hot path.

### 4.3 Reaper triggers

`shell/App/JugnuApp.swift`:
- **Launch:** after the safe-mode check (4.4), **before** the command index builds. Mode = `.degraded` if safe mode, else `.normal`.
- **Wake:** the `didWakeNotification` observer (stubbed in Phase 2) → `reap(mode:)`.
- **Pre-quit:** in `applicationWillTerminate`, after `host.killAll()`.
- No periodic sweep.

### 4.4 `LaunchGuard` — crash-loop counter + safe mode

Create `shell/App/LaunchGuard.swift`:
- Counter file: `~/.local/share/jugnu/state/launch-attempts` (dedicated tiny file — **not** `JugnuState` / `jugnu.yaml`, both parsed at startup and themselves suspect; a config reset must not wipe it).
- `init(fileURL:now:)` (inject clock, conventions).
- `func recordAttempt()` — increment, **atomic write** (temp + rename), called *before* risky startup work.
- `func markCleanLaunch()` — clear the counter, called at **idle-ready**: menu bar item mounted **and** hotkey registered **and** first `AppModel.bootstrap()` returned without throwing.
- `var shouldEnterSafeMode: Bool` — true iff the counter shows **3 consecutive** launches incremented-but-never-cleared. Crash and hang count identically (a hung startup the user force-quits is as fatal as a SIGSEGV — the "within N seconds" clause is **dropped**). A single clean launch resets → a one-off self-heals.
- **Any read failure** (missing / garbage / unreadable) → treated as **zero**, normal launch proceeds. A recovery mechanism must never be able to strangle the app.
- (Startup watchdog — self-terminate on hang — is a spec §10 *note*, **not built** here.)

### 4.5 Safe-mode entry

`shell/App/JugnuApp.swift`, when `LaunchGuard.shouldEnterSafeMode`:
- Menu-bar-only. **Zero addons loaded** (any class). Default theme forced. Config loaded defensively — a parse failure routes into the recovery surface.
- **On entry, boot out every `com.jugnu.*` launchd agent** — not just as a recovery action. A misbehaving `daemon` runs independently of the shell; skipping addon *loading* would not stop it. `launchctl bootout gui/<uid>/com.jugnu.*` (or enumerate + bootout each). A subsequent normal launch re-bootstraps enabled daemons as part of startup.
- Reaper runs in `.degraded` (4.2).
- Write `LifecycleEvent(event: "safe_mode", strikeCount:, ts:)` to `lifecycle.log` (all build configs).

### 4.6 Recovery surface (shared with ticket 0034 malformed-yaml)

- A menu-bar-only surface with four actions: (1) **Reset config to defaults**, (2) **Open config file**, (3) **Disable all addons**, (4) **Try normal launch again**.
- It is a **bisect surface** — config vs addon — since the shell does not know which caused the loop. (Agents are already booted out on entry, so "disable all + relaunch" is now about *config* + the enable flags.)
- Reuse whatever malformed-yaml (0034) surface exists or build the shared one here; do not build two.

### 4.7 Ticket 0034 — malformed `jugnu.yaml`

- On a YAML **syntax** error at load (not a bad scalar — the theme-hex fallback still handles those): block startup, show the recovery surface.

### 4.8 Tests

- `LaunchGuardTests` (App, temp file + injected clock):
  - increment → 3 consecutive uncleared → `shouldEnterSafeMode` true.
  - one `markCleanLaunch` between strikes → resets, no safe mode.
  - corrupt counter file → treated as zero, `shouldEnterSafeMode` false, normal launch.
  - hang simulation: `recordAttempt` called 3× with no `markCleanLaunch` → trip (identical to crash).
- `AddonReaperTests` (App, fixture markers + fixture processes):
  - directory parse tolerates garbage / missing dir.
  - **normal kill path:** a marker for a live orphan whose `shellPID`/`shellStartTS` has no live `Jugnu` → killed.
  - **spare path:** a marker whose `(shellPID, shellStartTS)` **does** match a live `Jugnu`-comm process → **not** killed.
  - **PID-reuse case:** a marker whose `shellPID` is now a live process but with a **different** `startTS` / comm name → the child is treated as orphaned and killed (reuse cannot spoof start-ts).
  - a marker for an `AddonProcessHost`-owned live entry → not killed.
  - stale marker (dead pid) → deleted.
  - degraded mode: kills without a manifest lookup.
- `test_safeMode_bootsOutAgentsOnEntry` (App, fake `launchctl`) — entering safe mode issues the `com.jugnu.*` bootout; recovery surface renders its four actions.
- `test_malformedYaml_routesToRecoverySurface`.

### 4.9 `docs/architecture/shell-smoke.md` — manual steps (load-bearing)

Add a **"Addon process lifecycle (0057)"** section. These cannot be CI-tested:
- [ ] **Reaper after a shell crash:** invoke a `disowns-child` fixture addon (or `pomodoro` pre-migration); `kill -9` the `Jugnu` process; relaunch; confirm the `state/run/<pid>.json` marker is gone **and** the orphaned `sleep` child (`pgrep -f sleep`) is gone; confirm one `reap` line in `lifecycle.log`.
- [ ] **Real sleep/wake:** start a `job` fixture; `pmset sleepnow`; wake; confirm the mid-flight `job` was torn down and did not resume as a zombie.
- [ ] **`job` stops heartbeating:** run the `stops-heartbeating` fixture as a `job`; confirm SIGKILL + error toast within ~`jobHeartbeatWindowMs`.
- [ ] **`make stop`:** with a `job` and a `daemon` both running, `make stop`; confirm no tracked child survives **but** the `com.jugnu.*` daemon agent is **still running** (`launchctl list | grep com.jugnu`).
- [ ] **Safe-mode entry:** force 3 hung/crashed launches (e.g. temporarily break `jugnu.yaml`); confirm safe mode boots out `com.jugnu.*` agents on entry (`launchctl list` before/after), the recovery surface shows, and one `safe_mode` line is in `lifecycle.log`; fix config → "Try normal launch again" → daemons re-bootstrapped.
- [ ] **PID reuse (best effort):** note a spawned child's `shell_pid`; after a crash + relaunch where the OS happens to reuse that pid, confirm the reaper still reaps by the start-ts mismatch.

### Review checkpoint — Phase 4

- [ ] Reaper kill authority is **all four** conditions in normal mode; the `(shell_pid, shell_start_ts)` + comm-name cross-check is present and PID-reuse-safe.
- [ ] Degraded mode does **no** manifest class lookup; leans on the `com.jugnu.*` bootout for markerless `daemon` orphans.
- [ ] Reaper triggers: launch (post-safe-mode-check, pre-index), wake, pre-quit. No periodic sweep. Never on the invoke path.
- [ ] `reap` + `safe_mode` events written in **all** build configs, capped file.
- [ ] Counter is a dedicated atomic-write file; read failure → zero; 3 consecutive uncleared → trip; crash == hang; one clean launch resets.
- [ ] Safe mode: zero addons, forced theme, **`com.jugnu.*` bootout on entry**, degraded reaper, recovery surface with the four actions.
- [ ] 0034 YAML **syntax** error → recovery surface; bad scalar still falls back.
- [ ] `shell-smoke.md` has the 0057 manual section with all six checks.
- [ ] `cd shell && swift test` green; `validate-addon.sh` green.

---

## Phase 5 — migrate the first consumers

Each addon change ends with its own suite green **and** `scripts/validate-addon.sh <addon>` passing.

### 5.1 `pomodoro` → `clock` helper

`addons/pomodoro/`:
- Replace `( sleep 1500; notify ) & disown` with a `clock` helper `upsert` (one-shot timer, `target.command` = a `pomodoro` chime command) — same pattern `nudges` uses.
- Delete the `& disown` line entirely.
- `pomodoro` stays `lifecycle: oneshot` (default) — the deferred chime is now the helper's job, not a leaked subshell.
- Update `addons/pomodoro/` tests + README.

### 5.2 `keep-awake` → `lifecycle: daemon`

`addons/keep-awake/`:
- `addon.yaml`: the watcher command gets `lifecycle: daemon` + a `daemon:` block (`program`, `args`, `keep_alive: true`). `keep-awake` is on the first-party allowlist.
- **Delete** the hand-rolled `launchctl bootstrap` code from `bin/run`.
- `cleanup.launchd` is now auto-populated from the `daemon` block — remove any hand-maintained entry.
- Update tests + README.

### 5.3 `clipboard-history` → `lifecycle: daemon`

`addons/clipboard-history/`:
- Same as 5.2: `lifecycle: daemon` + `daemon:` block; first-party allowlisted.
- **Delete** the hand-rolled `ensure_watcher` / `launchctl` bootstrap from `bin/run`.
- `cleanup.launchd` auto-populated.
- Update tests + README.

### 5.4 First-run bootstrap verification

- Verify the **first-run / first-install-with-enable** path bootstraps `clipboard-history`'s daemon through the on-enable `DaemonAgents.bootstrap` — **no lazy self-install** from the addon. Test in a temp `HOME` via the installer test pattern, or a `shell-smoke.md` manual step: fresh install → `launchctl list | grep com.jugnu.clipboard-history` present without ever invoking a command.

### 5.5 Docs + changelog

- `CHANGELOG.md` (Unreleased): addon process lifecycle (`AddonProcessHost`, `oneshot`/`job`/`daemon`), crash-recovery safe mode, orphan reaper; `pomodoro` / `keep-awake` / `clipboard-history` migrated off hand-rolled background work.
- `docs/tickets.md`: mark 0057 phases; note 0014 (Esc leaves a `Process`), the 0032 disable-alert slice, the 0034 YAML-syntax slice, and 0013 rename cleanups (`handleEsc` / `handleClickOutside`) as addressed here.
- `docs/backlog.md`: point the lifecycle row at this plan.

### 5.6 Tests

- Each migrated addon's suite green.
- `scripts/validate-addon.sh addons/pomodoro`, `addons/keep-awake`, `addons/clipboard-history` — all pass (the two daemons pass the first-party gate; `pomodoro` has no `disown` warning anymore).
- `cd shell && swift test` + `cd helpers/clock && swift test` green.

### Review checkpoint — Phase 5

- [ ] `pomodoro` has no `& disown`; deferred chime via `clock` helper; stays `oneshot`.
- [ ] `keep-awake` + `clipboard-history` are `lifecycle: daemon` + `daemon:` block, first-party allowlisted; hand-rolled `launchctl` code **deleted** from both `bin/run`s; `cleanup.launchd` auto-populated.
- [ ] First-run path bootstraps `clipboard-history`'s daemon with no lazy self-install (test or smoke step).
- [ ] All three `validate-addon.sh` runs pass; the `disown` warning no longer fires for `pomodoro`.
- [ ] `cd shell && swift test` + `cd helpers/clock && swift test` green.
- [ ] CHANGELOG + tickets + backlog updated.

---

## Spec coverage checklist

| Spec section | Phase(s) |
|---|---|
| §2 lifecycle-class model, locked decisions, named budgets | 1 (budgets), 3 (classes) |
| §3 `AddonProcessHost` | 1 (skeleton), 2 (edge kills), 3 (guard + `on_reinvoke`) |
| §4 `AddonRunner` spawn/wait split | 1 (`spawn`/`waitForResponse`/`terminate`), 3 (`job` watchdog) |
| §5 `daemon` shell-generated launchd agents | 3 |
| §6 orphan reaper — marker files | 1 (marker write/delete/enumerate), 4 (reaper) |
| §7 `on_reinvoke` | 3 |
| §8 crash-loop safe mode | 4 |
| §9 non-addon in-flight work, detached panels, dev workflow | 2 |
| §10 deferred (progress protocol, daemon authoring, watchdog) | **not built** — noted only |
| §11 sibling epics (`session`, install-integrity) | **not built** |
| §12 5-phase breakdown | 1–5 |
| Manual (shell-smoke.md) | 4.9 |

## Consistency notes

- `CommandKey` = `(addonID, commandID)` — one name, used by host, guard, reaper cross-check, disable alert.
- Marker filename is `<pid>.json` under `state/run/`; JSON key for the class is `class`, Swift property `lifecycleClass`.
- Budget constants are `*Ms` `Int` in `LatencyBudgets`, matching the existing style; spec's seconds → milliseconds here.
- First-party daemon allowlist lives in **two** places that must agree: `validate-addon.sh` (`FIRST_PARTY_DAEMON_IDS`) and `DaemonAgents.firstPartyDaemonIDs`. A single source would be nicer but crosses the bash/Swift boundary — keep them adjacent in review and add a `//` why on the Swift set pointing at the script.
- `lifecycle.log` is the interim sink (ticket 0019 subsumes it); `reap` + `safe_mode` in all configs, everything else `#if DEBUG`.
- Renames (`handleEsc` → `popOrDismiss`, `handleClickOutside` → `dismissFromClickOutside`) happen in Phase 2 as known-debt cleanup, not deferred.
