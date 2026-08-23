# Addon UI Host P1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Jugnu’s JSON `api: 1` run path so the shell can present shell-owned **toast / confirm / list / form** UI from addon responses, with latency instrumentation and skeleton-first panel chrome — without blocking toast-only v0 addons.

**Architecture:** `JugnuCore` decodes `RunRequest` / `RunResponse` (including optional `ui` + empty `context`). The app’s UI host owns NSPanel/SwiftUI chrome, maps `ui.pattern` to presenters, and re-invokes the same entrypoint with richer `args` on follow-up. Addons stay stdin/stdout JSON; they never create unmanaged windows.

**Tech Stack:** macOS 14+, Swift 5.9+, JugnuCore (SPM) + existing Jugnu app target from shell MVP, XCTest for protocol/decode/runner, manual UI checks on macOS.

**Spec:** [docs/architecture/2026-08-22-addon-ui-speed-design.md](../../architecture/2026-08-22-addon-ui-speed-design.md)
**Prerequisite:** [Shell MVP plan](./2026-08-22-shell-mvp.md) through **AddonRunner** + **Palette** (enough to run a command and show a toast/message). Do not implement P2 (`progress` / `status`) or P3 (context ranking) in this plan.

**Inline progress (2026-08-22):** P1 complete end-to-end — Core protocol + `JugnuUI` + demo addons; app palette wires `CommandInvoke` / `UIHostController` (`shell/App/AppModel.swift`). Manual UI verified working.

## Global Constraints

- Shell-owned UI only; no per-addon WebView/SwiftUI bundle loading.
- Toast responses `{ok, message|error}` remain valid with **zero** UI fields.
- Follow-ups: same `op: "run"`, richer `args` (frozen in spec).
- `context` may be present as `{}` or omitted; never send screen pixels.
- Published addons: no user Python.
- Prefer TDD on Core decode/runner; UI verified manually.
- Do not `git commit` unless the user explicitly asks in that session (repo rule).

---

## File map

```
shell/Sources/JugnuCore/
  Protocol/
    RunModels.swift              # RunRequest, RunResponse, UIDescriptor, patterns
    RunJSON.swift                # encode/decode helpers
  Latency/
    InvokeTrace.swift            # timestamps + budget helpers
  AddonRunner.swift              # (exists or from MVP) — timeouts: interactive vs default
shell/Tests/JugnuCoreTests/
  RunModelsTests.swift
  RunJSONTests.swift
  InvokeTraceTests.swift
  Fixtures/ui-host/              # fake entrypoints returning list/form/confirm JSON
shell/Jugnu/   # or App/ — match shell MVP layout when it lands
  UIHost/
    UIHostController.swift       # open/dismiss; route by pattern
    ToastPresenter.swift
    ConfirmPanel.swift
    ListPanel.swift
    FormPanel.swift
    SkeletonPanel.swift          # chrome-first while runner in flight
addons/
  ui-demo-list/                  # reference list addon (local/dev)
  ui-demo-form/
  ui-demo-confirm/
```

---

### Task 1: Run protocol models (`toast` + `ui`)

**Files:**
- Create: `shell/Sources/JugnuCore/Protocol/RunModels.swift`
- Create: `shell/Tests/JugnuCoreTests/RunModelsTests.swift`

**Interfaces:**
- Produces:
  - `public enum UIPattern: String, Codable, Sendable` — `list`, `form`, `confirm` (toast = no `ui`)
  - `public struct RunRequest: Codable, Sendable` — `api: Int`, `op: String`, `command: String`, `args: [String: JSONValue]`, `context: [String: JSONValue]?`
  - `public struct RunResponse: Codable, Sendable` — `ok: Bool`, `message: String?`, `error: String?`, `ui: UIDescriptor?`
  - `public struct UIDescriptor: Codable, Sendable` — `pattern: UIPattern`, `title: String?`, `placeholder: String?`, `message: String?` (confirm body), `items: [UIListItem]?`, `fields: [UIFormField]?`, `confirmLabel: String?`, `cancelLabel: String?`
  - `public struct UIListItem: Codable, Sendable` — `id`, `title`, `subtitle: String?`, `actions: [String]?`
  - `public struct UIFormField: Codable, Sendable` — `id`, `label`, `kind: String` (`text`|`number`|`toggle`), `value: JSONValue?`
  - `public enum JSONValue: Codable, Sendable, Equatable` — string/number/bool/null/object/array (minimal)

- [x] **Step 1–4: Protocol models + tests** (done inline 2026-08-22)

---

### Task 2: Run JSON helpers + follow-up args

**Files:**
- Create: `shell/Sources/JugnuCore/Protocol/RunJSON.swift`
- Create: `shell/Tests/JugnuCoreTests/RunJSONTests.swift`

**Interfaces:**
- Consumes: `RunRequest`, `RunResponse`, `JSONValue`
- Produces:
  - `public enum RunJSON`
  - `static func decodeResponse(stdout: Data) throws -> RunResponse`
  - `static func encodeRequest(_ request: RunRequest) throws -> Data`
  - `static func followUpRequest(command: String, args: [String: JSONValue]) -> RunRequest`
    → `RunRequest(api: 1, op: "run", command: command, args: args, context: [:])`

- [ ] **Step 1: Failing tests**

```swift
func testDecodeIgnoresTrailingWhitespace() throws {
    let data = "{\"ok\":true,\"message\":\"ok\"}\n".data(using: .utf8)!
    let r = try RunJSON.decodeResponse(stdout: data)
    XCTAssertEqual(r.message, "ok")
}

func testFollowUpIncludesItemId() throws {
    let req = RunJSON.followUpRequest(
        command: "list",
        args: ["itemId": .string("1234"), "action": .string("quit")]
    )
    XCTAssertEqual(req.op, "run")
    XCTAssertEqual(req.args["itemId"], .string("1234"))
}
```

- [ ] **Step 2: Run — FAIL**

Run: `cd shell && swift test --filter RunJSONTests`

- [ ] **Step 3: Implement helpers**

Trim whitespace; if decode fails, throw a clear `RunJSONError.invalidResponse`.

- [ ] **Step 4: Run — PASS**

- [ ] **Step 5: Commit only if user asked**

---

### Task 3: `InvokeTrace` latency helper

**Files:**
- Create: `shell/Sources/JugnuCore/Latency/InvokeTrace.swift`
- Create: `shell/Tests/JugnuCoreTests/InvokeTraceTests.swift`

**Interfaces:**
- Produces:
  - `public struct InvokeTrace: Sendable`
  - `public init(commandId: String, now: @escaping () -> Date = { Date() })`
  - `mutating func markFirstPaint()`
  - `mutating func markContent()`
  - `mutating func markDismiss()`
  - `var firstPaintMs: Int?`, `contentMs: Int?`, `totalMs: Int?`
  - `public struct LatencyBudgets` with static lets matching spec targets (palettePaintMs: 50, toastMs: 150, chromeMs: 100, contentMs: 300, followUpMs: 150) and hard ceilings
  - `func exceedsToastTarget() -> Bool` etc. as needed for logging

- [ ] **Step 1: Failing test with injectable clock**

```swift
func testFirstPaintDelta() {
    var t: TimeInterval = 1_000
    var trace = InvokeTrace(commandId: "x", now: { Date(timeIntervalSince1970: t) })
    t += 0.08
    trace.markFirstPaint()
    XCTAssertEqual(trace.firstPaintMs, 80)
}
```

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement**

Store `invokeAt`; on each mark compute ms since invoke. No network logging — `debugDescription` string only.

- [ ] **Step 4: Run — PASS**

---

### Task 4: Wire `AddonRunner` timeouts + decode `RunResponse`

**Files:**
- Modify: `shell/Sources/JugnuCore/AddonRunner.swift` (from shell MVP; create stub only if MVP task not done — prefer completing MVP Task 5 first)
- Modify: `shell/Tests/JugnuCoreTests/AddonRunnerTests.swift`
- Create fixtures under `shell/Tests/JugnuCoreTests/Fixtures/ui-host/`

**Interfaces:**
- Consumes: `RunJSON`, `RunRequest`, `RunResponse`
- Produces / updates:
  - `func run(addonRoot: URL, entrypointPath: String, request: RunRequest, timeout: TimeInterval) async throws -> RunResponse`
  - Default interactive timeout **0.8s**; optional `timeout: 5` for later progress (not used in P1 UI demos unless needed)
  - On non-JSON stdout or non-zero exit without `ok: false` JSON → `RunResponse(ok: false, error: …)`

- [ ] **Step 1: Fixture scripts**

`Fixtures/ui-host/echo-list.sh`:

```bash
#!/bin/bash
# reads stdin, ignores it, prints list UI
cat <<'EOF'
{"ok":true,"ui":{"pattern":"list","title":"Demo","items":[{"id":"a","title":"Alpha"}]}}
EOF
```

`echo-toast.sh` → `{"ok":true,"message":"hi"}`
`echo-confirm.sh` → confirm UI JSON
`echo-form.sh` → form UI JSON

`chmod +x` in test setup or store as executable in git.

- [ ] **Step 2: Failing test — list fixture returns `ui.pattern == list`**

```swift
func testRunnerDecodesListUI() async throws {
    let root = try fixtureUIHostDir()
    let runner = AddonRunner()
    let req = RunRequest(api: 1, op: "run", command: "demo", args: [:], context: [:])
    let res = try await runner.run(
        addonRoot: root,
        entrypointPath: "echo-list.sh",
        request: req,
        timeout: 0.8
    )
    XCTAssertEqual(res.ui?.pattern, .list)
}
```

- [ ] **Step 3: Implement/adjust runner to use `RunJSON.decodeResponse`**

- [ ] **Step 4: PASS for toast + list fixtures**

---

### Task 5: `UIHostController` routing (app)

**Files:**
- Create: `shell/Jugnu/UIHost/UIHostController.swift` (adjust path to match MVP app folder)
- Modify: palette “run selected command” handler to call UI host instead of only showing `message`

**Interfaces:**
- Consumes: `AddonRunner`, `RunResponse`, `InvokeTrace`, `CommandDescriptor` (from MVP)
- Produces:
  - `@MainActor final class UIHostController`
  - `func present(response: RunResponse, trace: inout InvokeTrace, followUp: @escaping (RunRequest) async -> RunResponse)`
  - Behavior:
    - `ok == false` → toast/error with `error`
    - `ui == nil` && ok → toast with `message`
    - `ui.pattern == .confirm|.list|.form` → corresponding panel

- [ ] **Step 1: Manual stub — compile app with UIHostController that switches on pattern and `NSLog`s**

- [ ] **Step 2: Hook palette: create `InvokeTrace`, call runner, `markContent` when response arrives, `present`

- [ ] **Step 3: Manual check — toast addon still works**

---

### Task 6: Toast presenter

**Files:**
- Create: `shell/Jugnu/UIHost/ToastPresenter.swift`

**Interfaces:**
- `func show(message: String, isError: Bool)`
- Auto-dismiss ~1.5s; respects reduced motion (no flashy animation if Reduce Motion on)

- [ ] **Step 1: Implement floating toast near palette or top-center**

- [ ] **Step 2: Manual — run mic-mute or toast fixture; toast within budget feel**

- [ ] **Step 3: On show, `trace.markFirstPaint()` if not already marked**

---

### Task 7: Confirm panel

**Files:**
- Create: `shell/Jugnu/UIHost/ConfirmPanel.swift`
- Fixture: `echo-confirm.sh` already from Task 4

**Interfaces:**
- Show `title` + `message`; buttons `confirmLabel` (default “Confirm”) / `cancelLabel` (default “Cancel”)
- Confirm → `followUp(RunJSON.followUpRequest(command:original, args: ["confirmed": .bool(true)]))`
- Cancel → dismiss; no runner call

- [ ] **Step 1: Implement panel (Esc = cancel)**

- [ ] **Step 2: Wire `UIHostController` case `.confirm`

- [ ] **Step 3: Manual — confirm then cancel paths**

Reference addon (optional local): `addons/ui-demo-confirm/` with `addon.yaml` command `demo` returning confirm UI on first run; second run with `confirmed: true` returns toast “Confirmed”.

---

### Task 8: List panel + follow-up

**Files:**
- Create: `shell/Jugnu/UIHost/ListPanel.swift`
- Create: `addons/ui-demo-list/addon.yaml` + `bin/run`

**Interfaces:**
- Search field filters `items` by title/subtitle locally (no re-query required for P1)
- Return/click row → follow-up args `itemId` + optional `action` (first action or “select”)
- Esc dismisses

**Demo `bin/run` behavior:**

```bash
# pseudocode
read JSON from stdin
if args.itemId set → echo toast ok "Chose $itemId"
else → echo list with 3 static items
```

- [ ] **Step 1: Implement ListPanel**

- [ ] **Step 2: Wire host + demo addon via local/dev override**

- [ ] **Step 3: Manual — open list, filter, select, see toast**

---

### Task 9: Form panel + follow-up

**Files:**
- Create: `shell/Jugnu/UIHost/FormPanel.swift`
- Create: `addons/ui-demo-form/addon.yaml` + `bin/run`

**Interfaces:**
- Render `fields` (`text` / `toggle` minimum for P1; `number` as text field OK)
- Submit → follow-up `args` = field id → JSONValue
- Cancel / Esc dismisses

Demo: first response returns form with one text field `name`; submit returns toast “Hello, {name}”.

- [ ] **Step 1: Implement FormPanel**

- [ ] **Step 2: Wire + demo addon**

- [ ] **Step 3: Manual — submit and cancel**

---

### Task 10: Skeleton-first chrome

**Files:**
- Create: `shell/Jugnu/UIHost/SkeletonPanel.swift`
- Modify: `UIHostController` + palette run path
- Optional: `addon.yaml` command field `ui: { pattern: list }` default (parse in ManifestLoader if present; else skip and only skeleton when you already know pattern from prior response — for P1, skeleton when manifest declares pattern)

**Spec rule:** Panel chrome visible before addon I/O completes when pattern is known.

- [ ] **Step 1: Extend command model (MVP `CommandDescriptor`) with optional `defaultUIPattern: UIPattern?` from `addon.yaml`**

Example yaml fragment:

```yaml
commands:
  - id: demo
    title: Demo list
    ui:
      pattern: list
```

- [ ] **Step 2: On invoke, if `defaultUIPattern != nil`, open SkeletonPanel immediately → `markFirstPaint` → run addon → replace skeleton with real panel or fill content → `markContent`**

- [ ] **Step 3: Manual — artificially `sleep 0.5` in demo list script; chrome appears before rows**

- [ ] **Step 4: Log `InvokeTrace.debugDescription` in DEBUG builds**

---

### Task 11: P1 verification checklist (no new features)

**Files:**
- Modify: `docs/architecture/2026-08-22-addon-ui-speed-design.md` — add “P1 verification” subsection under success criteria only if something was wrong; prefer checklist in plan completion note
- Modify: `shell/README.md` — how to run ui-demo-* locally

- [ ] **Step 1: Verify success criteria**

1. List demo: chrome before content when script sleeps.
2. Toast-only path unchanged.
3. Confirm / list / form follow-ups use `op: "run"`.
4. Esc dismisses panels.
5. `swift test` Core filters green.

- [ ] **Step 2: Explicitly defer P2/P3** — do not implement `progress` / `status` / real context population.

---

## Spec coverage (self-review)

| Spec section | Task(s) |
|---|---|
| Shell-owned patterns | 5–9 |
| toast / confirm / list / form | 6–9 |
| JSON `ui` response | 1–2, 4 |
| Follow-up `op: run` + args | 2, 7–9 |
| Empty `context` reserved | 1 |
| Latency budgets + trace | 3, 10 |
| Skeleton-first chrome | 10 |
| No WebView / custom bundles | Global + file map |
| P2/P3 out of scope | Task 11 + header |
| Toast backward compatible | 1, 6 |

**Not in this plan (by design):** `progress`, `status` menu-bar API, runner process pooling, context ranking, visual brand system.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-22-addon-ui-host-p1.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — execute tasks in this session with checkpoints

**Which approach?**

Note: if Shell MVP AddonRunner + Palette are not done yet, finish those MVP tasks first (or start with Tasks 1–3 here in parallel on Core).
