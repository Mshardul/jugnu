# Clock helper + nudges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship shared helper `clock` (first real `registry/helpers.json` package) plus catalog addon `nudges` with Shell `ClockHost` and a new detached `card` UI pattern.

**Architecture:** Helper exec owns timer CRUD + on-disk schedules (`~/.local/share/jugnu/state/clock/timers.json`). Shell `ClockHost` polls `due` while Jugnu runs and invokes addon targets. `nudges` owns rows/template YAML, syncs `nudges:<rowId>` timers, and returns `card` UI (huge emoji + firefly message + accent). PNG icons are ticket 0050 only — not this plan.

**Tech Stack:** Swift (helper Package + JugnuCore/JugnuUI), bash/exec addon entrypoint (same pattern as `floating-note` / `pomodoro`), YAML config, `api: 1` JSON protocol, XCTest.

**Spec:** [docs/architecture/2026-08-25-nudges-clock-helper-design.md](../../architecture/2026-08-25-nudges-clock-helper-design.md)

## Global Constraints

- Helper id `clock`, version `1.0.0`; not a catalog product; no enable key.
- Fire only while `Jugnu.app` is running; schedules persist; no catch-up spam on launch; no launchd.
- Emoji only this round; no PNG/SVG.
- New UI pattern `card` — do not overload `note` (TextEditor scratchpad).
- `nudges` declares `helpers: [{ id: clock, version: 1.0.0 }]`.
- User-facing errors only via existing plain-copy patterns — no paths/stacks.
- **Git:** do not create commits unless the user explicitly asked for commits in the session (repo AGENTS.md). Skip every “Commit” step below when commits were not requested; still mark the step done after verifying tests.
- Do not scaffold Play addons or wire kitchen-timer/pomodoro in this plan.

---

## File map

| Path | Responsibility |
|---|---|
| `helpers/clock/` | Swift PM: `ClockStore`, JSON protocol CLI `clock`, unit tests |
| `helpers/clock/helper.yaml` | Helper manifest |
| `registry/helpers.json` | First real helper catalog row (url + sha256 after pack) |
| `shell/Sources/JugnuCore/Protocol/RunModels.swift` | `UIPattern.card`; `UIDescriptor.emoji` / `accent` |
| `shell/Sources/JugnuCore/ViewType.swift` | `card` → nil view type (detached like `note`) |
| `shell/Sources/JugnuCore/Paths.swift` | `stateDir`, `clockTimersFile` |
| `shell/Sources/JugnuCore/ClockClient.swift` | Spawn helper exec; encode ops |
| `shell/Sources/JugnuCore/ClockHost.swift` | Poll due → invoke target → mark-fired |
| `shell/Sources/JugnuUI/CardPanel.swift` | Huge emoji + message + accent wash |
| `shell/Sources/JugnuUI/ShellHost.swift` | `openCard` parallel to `openNote` |
| `shell/App/JugnuApp.swift` | Start/stop `ClockHost` with app lifetime |
| `addons/nudges/` | Catalog zip: `addon.yaml`, `bin/run`, state YAML schema |
| `docs/tickets.md` | 0049 implement, 0050 PNG follow-up |
| `docs/backlog.md` | Mark nudges as in progress / point at spec |
| `docs/architecture/shell-smoke.md` | Manual nudge/card/clock checks |
| `CHANGELOG.md` | Unreleased notes |

---

### Task 1: Tickets + docs pointers

**Files:**
- Modify: `docs/tickets.md` (append 0049, 0050)
- Modify: `docs/backlog.md` (nudges row / System QoL note → link spec + 0049)
- Modify: `docs/architecture/2026-08-25-nudges-clock-helper-design.md` (status already Approved — verify ticket links)
- Modify: `CHANGELOG.md` (Documentation bullet under Unreleased)

**Interfaces:**
- Consumes: approved spec
- Produces: ticket ids **0049** (implement clock+nudges), **0050** (PNG icons follow-up, Not started, blocked on 0049 Done)

- [x] **Step 1: Append tickets**

Add rows (match existing table columns):

| 0049 | `clock` helper + `nudges` addon | Shared timer helper + nudges mini-tool (user list, 3 presets, `card` UI, Shell ClockHost). Spec: [2026-08-25 nudges-clock-helper](architecture/2026-08-25-nudges-clock-helper-design.md). Plan: [2026-08-25-nudges-clock-helper](superpowers/plans/2026-08-25-nudges-clock-helper.md). Emoji only; PNG is 0050. | High | L | 0047 | Not started | 2026-08-25 | 2026-08-25 | First real helpers.json package. |

| 0050 | Nudges: custom PNG icons on cards | Optional PNG override per nudge row (Advanced/config path first; file picker later). SVG deferred. Schema/UI after emoji-only ship. | Medium | M | 0049 | Not started | 2026-08-25 | 2026-08-25 | Locked out of 0049 deliberately. |

- [x] **Step 2: Point backlog nudges at 0049**

In `docs/backlog.md`, on the `nudges` / eye-rest packaging lines, add a short note: “Implementing — 0049 / spec 2026-08-25”.

- [x] **Step 3: CHANGELOG documentation bullet**

`- 2026-08-25 — Approved clock helper + nudges design; plan under docs/superpowers/plans/.`

- [x] **Step 4: Commit** (skip unless user asked for git commits)

```bash
git add docs/tickets.md docs/backlog.md CHANGELOG.md docs/architecture/2026-08-25-nudges-clock-helper-design.md
git commit -m "$(cat <<'EOF'
docs: ticket 0049 clock+nudges and 0050 PNG follow-up

EOF
)"
```

---

### Task 2: Clock helper — store + protocol (TDD)

**Files:**
- Create: `helpers/clock/Package.swift`
- Create: `helpers/clock/Sources/ClockCore/ClockModels.swift`
- Create: `helpers/clock/Sources/ClockCore/ClockStore.swift`
- Create: `helpers/clock/Sources/ClockCLI/main.swift`
- Create: `helpers/clock/Tests/ClockCoreTests/ClockStoreTests.swift`
- Create: `helpers/clock/helper.yaml`

**Interfaces:**
- Consumes: none
- Produces:
  - `struct ClockTimer: Codable, Equatable` with `id`, `kind` (`interval`|`oneShot`), `intervalSeconds: Int?`, `fireAt: Date?`, `enabled: Bool`, `paused: Bool`, `nextFire: Date`, `group: String?`, `target: ClockTarget`
  - `struct ClockTarget: Codable, Equatable` with `addon: String`, `command: String`
  - `enum ClockOp: String` — `upsert`, `cancel`, `pause`, `resume`, `list`, `due`, `markFired`, `snooze`
  - `struct ClockRequest` / `ClockResponse` (JSON)
  - `final class ClockStore` — `init(fileURL: URL)`, methods matching ops; file at caller-chosen URL
  - CLI: read one JSON object from stdin, write one JSON object to stdout, exit 0 on `ok: true`

- [x] **Step 1: Write failing store tests**

```swift
func testUpsertAndDue() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("clock-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = ClockStore(fileURL: url)
    let past = Date().addingTimeInterval(-1)
    try store.upsert(ClockTimer(
        id: "nudges:eyes",
        kind: .interval,
        intervalSeconds: 1200,
        fireAt: nil,
        enabled: true,
        paused: false,
        nextFire: past,
        group: "nudges",
        target: ClockTarget(addon: "nudges", command: "show-card")
    ))
    XCTAssertEqual(try store.due(now: Date()).map(\.id), ["nudges:eyes"])
}

func testPausedNotDue() throws { /* upsert paused=true → due empty */ }

func testMarkFiredAdvancesInterval() throws {
    // nextFire was past; after markFired, nextFire ~= now+intervalSeconds
}
```

- [x] **Step 2: Run tests — expect fail**

```bash
cd helpers/clock && swift test --filter ClockStoreTests
```

Expected: fail (module missing).

- [x] **Step 3: Implement Package + models + store**

`helper.yaml`:

```yaml
id: clock
version: 1.0.0
```

`ClockStore` persistence: single JSON file `{ "timers": [ ... ] }`. `markFired` for `.interval`: `nextFire = now + intervalSeconds`. For `.oneShot`: remove or set `enabled = false` (prefer remove). `pause`/`resume` by id or by `group` when request includes `"group": "nudges"` and omits id. `snooze`: `nextFire = now + seconds` (implement; nudges UI ignores).

- [x] **Step 4: Implement CLI `main.swift`**

Decode `ClockRequest` from stdin Data; switch on `op`; print `ClockResponse` JSON (`ok`, `timers?`, `error?`).

- [x] **Step 5: Run tests — expect pass**

```bash
cd helpers/clock && swift test
```

Expected: PASS.

- [x] **Step 6: Commit** (skip unless asked)

```bash
git add helpers/clock
git commit -m "$(cat <<'EOF'
feat(clock): helper store and JSON CLI

EOF
)"
```

---

### Task 3: Package helper + registry row (dev path)

**Files:**
- Create: `scripts/package-helper-clock.sh` (or extend existing pack script if one exists — prefer small dedicated script)
- Modify: `registry/helpers.json`
- Modify: `Makefile` (target `helper-clock` building release binary into staging)

**Interfaces:**
- Consumes: Task 2 binary
- Produces: zip layout `helper.yaml` + `bin/clock` executable; `registry/helpers.json` entry with `id`, `version`, `url`, `sha256` (local `file:` URL ok for dev, same pattern as addon local installs)

- [x] **Step 1: Build release binary into staging**

```bash
cd helpers/clock && swift build -c release
# copy .build/release/clock → dist/clock-1.0.0/bin/clock
# copy helper.yaml → dist/clock-1.0.0/helper.yaml
# zip → dist/clock-1.0.0.zip
shasum -a 256 dist/clock-1.0.0.zip
```

- [x] **Step 2: Write `registry/helpers.json`**

Replace `[]` with one object after computing sha256 of the zip:

```json
[
  {
    "id": "clock",
    "version": "1.0.0",
    "url": "https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0/clock-1.0.0.zip",
    "sha256": "<sha256 of clock-1.0.0.zip>"
  }
]
```

(Use the same release tag/hosting pattern as `registry/addons.json`. Until the asset is uploaded, local smoke uses `installHelperFromLocalZip`.)

- [x] **Step 3: Smoke install helper via unit-style call or small script**

```bash
# After building zip, optional:
swift test --filter HelperInstallTests
```

Expected: existing helper tests still PASS. Add one test `testClockHelperYamlLoads` if useful — optional.

- [x] **Step 4: Commit** (skip unless asked)

---

### Task 4: Protocol — `card` pattern + descriptor fields

**Files:**
- Modify: `shell/Sources/JugnuCore/Protocol/RunModels.swift`
- Modify: `shell/Sources/JugnuCore/ViewType.swift`
- Modify: `shell/Tests/JugnuCoreTests/RunModelsTests.swift`
- Modify: `shell/Tests/JugnuCoreTests/ViewTypeTests.swift`

**Interfaces:**
- Consumes: existing `UIPattern` / `UIDescriptor`
- Produces:
  - `UIPattern.card`
  - `UIDescriptor.emoji: String?`
  - `UIDescriptor.accent: String?` (CSS-like `#RRGGBB` or `#RRGGBBAA`)
  - `ViewType.resolve` returns `nil` for `.card` (same as `.note`)
  - `UIPattern.defaultViewType` for `.card` is `nil`

- [x] **Step 1: Failing decode test**

```swift
func testDecodesCardUI() throws {
    let json = """
    {"ok":true,"ui":{"pattern":"card","emoji":"👀","message":"Glow farther.","accent":"#4A90D9","title":"Eyes"}}
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
    XCTAssertEqual(decoded.ui?.pattern, .card)
    XCTAssertEqual(decoded.ui?.emoji, "👀")
    XCTAssertEqual(decoded.ui?.accent, "#4A90D9")
}
```

```swift
func testCardResolvesNilViewType() throws {
    XCTAssertNil(try ViewType.resolve(pattern: .card, requested: nil, allowed: ViewType.shellDefaults))
}
```

- [x] **Step 2: Run — expect fail**

```bash
cd shell && swift test --filter testDecodesCardUI
```

- [x] **Step 3: Extend models + ViewType**

Update `UIDescriptor` init and Codable synthesis (add properties with defaults `nil`). Update every `switch` on `UIPattern` in Core/UI that is non-exhaustive — compiler will guide (`ShellHost`, etc. may wait until Task 5).

- [x] **Step 4: Run — expect pass**

```bash
cd shell && swift test --filter RunModelsTests
cd shell && swift test --filter ViewTypeTests
```

- [x] **Step 5: Commit** (skip unless asked)

---

### Task 5: `CardPanel` + ShellHost wiring

**Files:**
- Create: `shell/Sources/JugnuUI/CardPanel.swift`
- Modify: `shell/Sources/JugnuUI/ShellHost.swift`
- Modify: `shell/Package.swift` if new file needs target membership (SPM picks up Sources automatically)

**Interfaces:**
- Consumes: `UIDescriptor` with `.card`, `emoji`, `message`, `accent`
- Produces: `CardPanel` NSPanel host; `ShellHost.openCard(ui:)`; dismiss on Esc/close; click-outside dismisses; duplicate same title/emoji replaces/focuses existing card (track weak refs by row key = `ui.title` + `emoji` or pass `args.rowId` later — use `title` as key for v1)

- [x] **Step 1: Implement `CardPanel`**

SwiftUI content:
- Vertical stack: emoji `Text` at ~72–96pt, message at title/body token size from `JugnuTokens`, background wash from `accent` (parse hex → Color; invalid → theme secondary fill)
- Reduce Motion: skip scale animation; otherwise short scale/fade on appear (~200ms)
- Panel: floating, nonactivating as appropriate; closable; **not** a TextEditor

Mirror `NotePanel` hosting pattern (NSHostingView in NSPanel) but display-only — no save follow-up.

- [x] **Step 2: Wire `ShellHost`**

In `present` / response handling, branch `ui.pattern == .card` like `.note`: call `openCard`, hide launcher. Do **not** push onto in-panel stack.

- [x] **Step 3: Manual compile**

```bash
cd shell && swift build
```

Expected: PASS.

- [x] **Step 4: Optional UI demo addon command** (only if needed for smoke) — prefer using nudges in Task 8; skip extra demo zip unless compile needs a fixture.

- [x] **Step 5: Commit** (skip unless asked)

---

### Task 6: `ClockClient` + `ClockHost` in Core/App

**Files:**
- Modify: `shell/Sources/JugnuCore/Paths.swift`
- Create: `shell/Sources/JugnuCore/ClockClient.swift`
- Create: `shell/Sources/JugnuCore/ClockHost.swift`
- Create: `shell/Tests/JugnuCoreTests/ClockClientTests.swift`
- Modify: `shell/App/JugnuApp.swift` (or `AppDelegate`) to start/stop host

**Interfaces:**
- Consumes: helper exec at `helperRoot(id:"clock", version:)/bin/clock`; timers file `stateDir/clock/timers.json`
- Produces:
  - `JugnuPaths.stateDir` → `~/.local/share/jugnu/state`
  - `JugnuPaths.clockTimersFile` → `stateDir/clock/timers.json`
  - `ClockClient.run(_ request: ClockRequest) throws -> ClockResponse` (sets env or passes `--file` path — **prefer explicit file URL argument in JSON request** `"file": "<path>"` so tests don’t depend on HOME)
  - `ClockHost`: `start(invoke: (addon:command:) async throws -> Void)`, `stop()`; timer every 2.0s (constant); for each due: invoke target; on success `markFired`; on failure toast/log via callback, backoff by leaving due until next tick **once**, then `markFired` after second failure to avoid hot loop (document in code comment)

- [x] **Step 1: Extend Paths**

```swift
public var stateDir: URL {
    home.appendingPathComponent(".local/share/jugnu/state")
}
public var clockTimersFile: URL {
    stateDir.appendingPathComponent("clock/timers.json")
}
```

- [x] **Step 2: Failing client test with fake exec** (or call `ClockStore` in-process for Core tests)

Prefer **in-process** `ClockStore` tests already in helper package. For Core, test `ClockHost` with a protocol:

```swift
protocol ClockServicing: Sendable {
    func due(now: Date) throws -> [ClockTimer]
    func markFired(id: String, now: Date) throws
}
```

`ClockHost` depends on `ClockServicing` + invoke closure. Production adapter shells out via `ClockClient`.

- [x] **Step 3: Implement host + client**

`ClockClient` locates binary: `paths.helperRoot(id: "clock", version: "1.0.0").appendingPathComponent("bin/clock")`. If missing, `due` returns `[]` and host no-ops (nudges install will place helper).

Pass `"file": paths.clockTimersFile.path` in every request.

- [x] **Step 4: Start host from app lifecycle**

On finish launch: `clockHost.start`. On terminate: `clockHost.stop`. Invoke path must call existing addon runner used for palette commands (same `AppModel` / runner entry).

- [x] **Step 5: Tests**

```bash
cd shell && swift test --filter ClockHost
```

Expected: PASS (paused not invoked; markFired after success).

- [x] **Step 6: Commit** (skip unless asked)

---

### Task 7: `nudges` addon — config + sync + show-card

**Files:**
- Create: `addons/nudges/addon.yaml`
- Create: `addons/nudges/bin/run`
- Create: `addons/nudges/README.md` (short: job, presets, Advanced config path)
- Create: factory `nudges.yaml` defaults embedded in `bin/run` or `addons/nudges/resources/defaults.yaml`

**Interfaces:**
- Consumes: `JUGNU_HELPER_CLOCK` env (runner sets), clock CLI, Shell `card` pattern
- Produces: state file `~/.local/share/jugnu/state/nudges/nudges.yaml` with `template` + `rows`; commands below

`addon.yaml` (lock):

```yaml
id: nudges
name: Nudges
version: 1.0.0
api: 1
helpers:
  - id: clock
    version: 1.0.0
view_types: [rows, fields, ask]
commands:
  - id: manage
    title: Nudges
    subtitle: Add, edit, and enable nudge timers
    keywords: [nudge, wellness, break, water, eyes, stretch]
    view: rows
  - id: nudge-now
    title: Nudge now
    subtitle: Show a nudge card immediately
    keywords: [nudge, preview]
    view: rows
  - id: pause
    title: Pause nudges
  - id: resume
    title: Resume nudges
  - id: restore-presets
    title: Restore nudge presets
  - id: advanced
    title: Nudge advanced
    subtitle: Edit new-nudge template
    view: fields
  - id: show-card
    title: Show nudge card
    subtitle: Internal — fired by clock
    keywords: []
entrypoint:
  kind: exec
  path: bin/run
cleanup:
  paths:
    - "~/.local/share/jugnu/state/nudges"
  launchd: []
```

Hide `show-card` from launcher if the shell supports a `hidden` flag — if not, keep keywords empty and title clear it’s internal; do not advertise in README.

- [x] **Step 1: Seed logic in `bin/run`**

On first run (no yaml): write three presets (eye-rest / water / stretch) + factory template. Call clock `upsert` for each enabled row (`group: nudges`, `target.command: show-card`, args later via context — for show-card, put `rowId` in timer id `nudges:<rowId>` and have show-card load row from yaml).

- [x] **Step 2: `show-card` command**

Resolve row by timer id / args `rowId`. Return:

```json
{"ok":true,"ui":{"pattern":"card","title":"<title>","emoji":"<emoji>","message":"<message>","accent":"<accent-or-omit>"}}
```

- [x] **Step 3: `pause` / `resume`**

Clock op with `"group":"nudges"`.

- [x] **Step 4: `restore-presets`**

Re-add any missing preset ids; upsert timers; toast message.

- [x] **Step 5: Validate manifest**

```bash
scripts/validate-addon.sh addons/nudges
```

Expected: PASS.

- [x] **Step 6: Commit** (skip unless asked)

---

### Task 8: Manage + Add + Advanced UI

**Files:**
- Modify: `addons/nudges/bin/run` (list/form JSON)
- Optional thin Swift tests only if parsing extracted — otherwise manual + scripted JSON fixtures under `addons/nudges/tests/` if repo pattern exists

**Interfaces:**
- Consumes: Task 7 yaml schema
- Produces:
  - `manage` → `list`/`rows` of nudges (emoji + title + enabled + interval subtitle); actions: toggle, edit, delete
  - Add action → prefilled `form`/`fields` in **follow-up** using template values (same manage flow, not a separate window chrome) — match existing list→form follow-up pattern from `ui-demo-form` / FormPanel `op: run`
  - `advanced` → form editing template fields; write yaml; optional message with config path for power users (`~/.local/share/jugnu/state/nudges/nudges.yaml`) without dumping raw paths in error toasts — path in success message is OK if other addons do it; else “Template saved”
  - Reset template: form button / confirm → factory template
  - Every save: validate interval > 0 and non-empty message; sync clock upsert/cancel

- [x] **Step 1: Implement list payload for `manage`**

Follow `ui-demo-list` item shape (`id`, `title`, `subtitle`, `actions`).

- [x] **Step 2: Implement follow-ups** (`op: run` with args from selection)

Edit/Add save writes yaml + clock sync.

- [x] **Step 3: Implement `nudge-now`**

List rows → on select call same UI as `show-card`.

- [x] **Step 4: Manual smoke script** (document in README)

```bash
# With helper installed and Jugnu running later — for now:
echo '{"api":1,"op":"run","command":"manage","args":{}}' | JUGNU_HELPER_CLOCK=/path/to/helper/root addons/nudges/bin/run
```

Expected: JSON `ok` + `ui.pattern` list/rows.

- [x] **Step 5: Commit** (skip unless asked)

---

### Task 9: End-to-end wire — install path + registry addon row

**Files:**
- Modify: `registry/addons.json` (add `nudges` entry when packaging script exists — follow `scripts` used for other addons)
- Modify: `addons/README.md` (list nudges)
- Modify: `docs/architecture/shell-smoke.md` (checklist section)

**Interfaces:**
- Consumes: packaged `nudges` zip + `clock` helper zip
- Produces: installable pair; smoke checklist

- [x] **Step 1: Package nudges zip** (mirror other addon release scripts)

Include `addon.yaml` + `bin/run` (+defaults). Compute sha256; update `registry/addons.json`.

- [x] **Step 2: Ensure install pulls helper**

Install nudges in a temp HOME via existing installer tests pattern or manual Jugnu Browse Catalog with local registry — verify `~/.local/share/jugnu/helpers/clock/1.0.0/bin/clock` exists after install.

- [x] **Step 3: Extend shell-smoke.md**

Checklist:
- [ ] Enable Nudges → three presets visible
- [ ] Set one interval to 30s (test) → card appears with huge emoji
- [ ] Dismiss card → no duplicate stack
- [ ] Pause nudges → no fire; Resume → fires again
- [ ] Delete a preset → Restore presets brings it back
- [ ] Add custom nudge from template → appears and schedules
- [ ] Quit Jugnu → no fire; relaunch → schedules resume without burst of missed cards

- [x] **Step 4: Full test suite**

```bash
cd helpers/clock && swift test
cd shell && swift test
scripts/validate-addon.sh addons/nudges
```

Expected: all PASS.

- [x] **Step 5: Mark 0049 Done in tickets.md when smoke walked; leave 0050 Not started**

- [x] **Step 6: CHANGELOG Added bullets** for clock helper, nudges, `card` pattern

- [x] **Step 7: Commit** (skip unless asked)

---

### Task 10: Spec self-check + polish polish

**Files:**
- Modify: `docs/architecture/2026-08-25-nudges-clock-helper-design.md` only if implementation forced a lock change (document deviation in Remarks on 0049)
- Modify: `addons/nudges/bin/run` copy strings (firefly voice)

**Interfaces:**
- Consumes: shipped behavior
- Produces: final copy for three presets + template; no product lock changes without updating spec

- [ ] **Step 1: Set preset messages** (firefly)

Examples (tune for taste, keep kind):
- Eyes: `Glow somewhere farther away for a bit.`
- Water: `Your cells called. They’re thirsty.`
- Stretch: `Uncurl. The chair will survive.`

- [ ] **Step 2: Confirm out-of-scope still out**

No PNG picker, no quiet hours UI, no snooze on card, no Play wiring.

- [ ] **Step 3: Commit** (skip unless asked)

---

## Spec coverage checklist

| Spec section | Task(s) |
|---|---|
| §2 presets / deletable / restore | 7, 8 |
| §2 template + Advanced + Reset | 8 |
| §2 fire card emoji + accent | 4, 5, 7 |
| §2 emoji only / PNG later | 1 (0050), Global Constraints |
| §2 fire only while running | 6 |
| §3 clock helper ops + target | 2, 3 |
| §3 Shell ClockHost | 6 |
| §3 nudges sync / cleanup | 7, 9 |
| §4 `card` pattern | 4, 5 |
| §5 commands | 7, 8 |
| §6 yaml data | 7, 8 |
| §7 errors | 6, 8 |
| §8 testing | 2, 4, 6, 9 |
| §9 out of scope | Global Constraints, Task 10 |

## Placeholder / consistency review

- Timer id prefix `nudges:` and group `nudges` used consistently.
- Helper version `1.0.0` everywhere.
- `show-card` is the fire target command id.
- State files: clock timers vs nudges yaml — separate paths under `state/`.
- No TBD left in tasks; packaging URL string must be filled from existing `registry/addons.json` convention when editing `helpers.json`.
