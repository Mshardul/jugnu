# Jugnu coding conventions

Standing engineering rules for this repo. Workflow, local checks, pull requests, and changelog live in [CONTRIBUTING.md](../CONTRIBUTING.md). Product intent lives in [vision.md](vision.md). The *why* for contracts and budgets lives in [architecture/](architecture/).

Every change is judged by **invoke → visible result**. If it adds work before first paint, opens a second window, or pulls addon logic into `Jugnu.app`, it is the wrong change.

**Reuse before invent.** New collections, caches, windows, runners, or patterns need one line in the PR: why the existing type is wrong. Default is no. Do not introduce a DI container, a second index, or a new “manager” because a tutorial had one. A linear scan of commands is the right search structure at this scale; “optimizing” it is usually the bug.

Copy the **current** pattern in the type table, not leftover names or comments. Known debt (do not clone):

| Do not copy | Copy instead | Cleanup |
|---|---|---|
| `handleEsc` / `handleClickOutside` | Outcome names (`popOrDismiss`, `dismiss`) | [0013](tickets.md) |
| `///` / `/* */` / “Task N” notes | No comment, or one `//` **why** | [0013](tickets.md) |
| `PrefsView` in `App/` | Views in `JugnuUI` | [0013](tickets.md) |
| Addon `Process` that outlives hide/Esc | Cancel + `cleanup` on leave | [0014](tickets.md) |
| `hide()` setting `panel = nil` | Keep the `KeyablePanel`; `orderOut` only | [0016](tickets.md) |
| `AddonInstaller.unzip()` as-is | Path-safe extract | [0003](tickets.md) |

## Vocabulary

Use product terms only:

| Term | Meaning |
|---|---|
| **Category** | Browse/group taxonomy. Not a zip. |
| **Addon** | One installable zip and one enable key. Commands and/or popup UI for one job. |
| **Commands** | Palette / menu actions inside that addon (`addon.yaml` `commands`). |
| **UI** | Panels, pickers, forms, previews for that addon (same zip). |
| **View type** | Shell-owned viewport id (`seek`, `palette`, `ask`, `fields`, `rows`, `grid`, `board`, `spread`, `canvas`, `rail`). Size band + panel aspect + dismiss rules. Not pixels. Catalog: [view types](architecture/2026-08-24-view-types.md). |
| **Zone** | Named saved **geometry** on `window-layouts` (max 6). Not occupancy. Not undo. |

Name addons and commands for the user's job (`mute-all`, not `call-mute-all`). Related commands share an addon; unrelated jobs do not. Popup UI and speed are part of every job.

## Layering

Dependencies only flow **App → JugnuUI → JugnuCore**. Core must stay UI-free.

| Layer | Path | Owns | Must not |
|---|---|---|---|
| **Jugnu** (executable) | `shell/App/` | `NSApplication`, hotkey, menu bar, wiring | Reimplement search, JSON protocol, or panel chrome |
| **JugnuUI** | `shell/Sources/JugnuUI/` | Panels, `ShellHost`, presets, tokens, theme | Spawn `Process` or talk to the registry |
| **JugnuCore** | `shell/Sources/JugnuCore/` | Manifest, index, fuzzy, runner, installer, registry, run protocol, traces | Import AppKit or SwiftUI |

- Match the Swift version and macOS deployment target in `shell/Package.swift`. Do not raise either without a concrete requirement.
- Add Swift packages only with a concrete need (today: Yams in Core, HotKey in App).
- Library types are `public`; App types are internal.
- Do not grow `ThemeStore.shared` into a dump for non-theme state.
- Inject clock, paths, and reduce-motion as closures (`InvokeTrace(now:)`, `JugnuPaths(home:)`, `ShellHost(reduceMotion:)`). Do not add a DI container.

## Reach for this type

| Job | Use | Do not invent |
|---|---|---|
| Search | `CommandIndex` + `Fuzzy` | A second index, on-disk search, a new scorer on the hot path |
| Run addon | `AddonRunner` + `RunJSON` (`api: 1`) | Sockets, in-process plugins, process pools |
| Paths | `JugnuPaths` | String-concatenated `~/` paths |
| Errors | Typed `*Error` / `*Failure` + `UserFacingError` | `localizedDescription` in a toast |
| Timing | `InvokeTrace` | `Date()` prints or ad-hoc timers on invoke |
| Panel / navigation | `ShellHost` + `ShellPreset` + `ShellStack` | Extra `NSWindow` or a second host |
| Theme / spacing | `JugnuTokens` / theme store | Magic numbers, per-view palettes |
| Protocol JSON | `JSONValue`, `RunRequest`, `RunResponse` | `[String: Any]` in Core |
| Catalog query | `BrowseCatalogFilter` | Ad-hoc filter logic in the view |
| Config / state | `ConfigStore` / `StateStore` | `UserDefaults` in views |
| Invoke UI | `CommandInvoke` (skeleton, then run) | Blocking the palette until `Process` exits |

A new type is allowed when none of these can express the job. Put that argument in the PR, not in a comment.

## Config, state, and data flow

A new fact belongs in **one** home. Do not add `UserDefaults`, a `static var`, or an untyped config map because it was convenient.

| Home | Holds | Does not hold |
|---|---|---|
| **Product law** | Budgets, tokens, protocol shape, timeouts, taxonomy, user-facing error copy | Anything a user would toggle |
| **Config** | User intent that survives relaunch and belongs in Preferences or a documented yaml field | Logs, recents, flags the user would not look for |
| **State** | Machine-local memory; loss is acceptable | Prefs, budgets, protocol keys |
| **Call / environment** | This invocation, this screen, this clock, this home directory, OS appearance / Reduce Motion | Process-wide app memory |

New prefs get a **typed** config field. Do not grow a stringly-typed dump. Addons do not read host config; stdin is the contract (`api`, `op`, command, args, empty `context` in v1).

**Process-wide objects we own** are almost never allowed. Apple’s process objects (`NSApplication`, `NSWorkspace`) are not ours. One paint bus for live chrome (theme / sound) is allowed so views can redraw without the composition root leaking into JugnuUI — put nothing else on it. Writes to that bus come from App when config is saved, not from leaf views.

**Composition root is App.** It owns paths, stores, runner, and published config/state. Core types that touch disk take paths in; tests pass a temp home. Do not read the real home inside a function that already has paths.

**Pass by value** across Core and the JSON boundary (snapshots, descriptors, stack entries). **Pass closures** at AppKit / SwiftUI seams (motion, clock, confirm/cancel). **Pass the panel’s screen**, not the main display, when morphing from an already-visible panel. JugnuUI takes descriptors and callbacks — not the composition root, not `@EnvironmentObject` of App types. Do not add a DI container; paths / clock / Reduce Motion injection is the seam. Protocols stay at FS / process / clock / network / clipboard (and view-model protocols the UI already uses).

In-flight work lives on the host that dismisses, not on a static “current run.” A singleton that outlives hide is a leak.

## Hot path

Budgets are in `LatencyBudgets` (`shell/Sources/JugnuCore/Latency/InvokeTrace.swift`) and [addon UI and speed](architecture/2026-08-22-addon-ui-speed-design.md) §6. Missing a target is a bug. Missing a ceiling needs an explicit `progress` pattern, not a hung palette.

| Path | Target | Hard ceiling |
|---|---|---|
| Hotkey → palette first paint | 50 ms | 100 ms |
| Command → panel chrome (skeleton OK) | 100 ms | 200 ms |
| Command → toast visible | 150 ms | 400 ms |
| Panel chrome → useful content | 300 ms | 800 ms |
| Follow-up action → feedback | 150 ms | 400 ms |

Default runner timeout is **0.8 s** (`AddonRunner`). Instant paths fail fast.

Invoke is: hotkey → `ShellHost.orderFront` → `PaletteView`. Search is in-memory `Fuzzy` over `CommandIndex`. Addon work starts only after chrome is committed (`CommandInvoke` skeleton, then `Task.detached` → `AddonRunner`).

**Forbidden between key-down and first paint:** filesystem walks, YAML decode, unzip, `URLSession`, `Process`, registry fetch, index rebuild, tearing down and recreating the panel.

- Keep `CommandIndex` in memory. Rebuild on enable/install, not every hotkey or keystroke.
- If `defaultUIPattern` is known, show skeleton chrome before the process returns.
- Reuse one `KeyablePanel` (`ensurePanel` is create-once). Destroy-on-hide recolds the 50 ms budget.
- Debounce search (~100 ms). Ranking stays O(commands), not O(disk).
- Entrypoints stay tiny. A Python/node cold start cannot hit toast 150 ms.
- Mark `InvokeTrace` firstPaint / content / dismiss. Log timing and ids only — never payloads.

## Concurrency

**On MainActor:** `AppModel`, `ShellHost`, views, `orderFront`, stack mutations.

**Off MainActor:** process wait, run-protocol JSON, unzip, HTTP, directory scans, SHA-256, cleanup.

Core types are `struct` + `Sendable`. UI types are `@MainActor` classes. Never `DispatchGroup.wait` on the main actor. Do not block the main actor with filesystem, process, archive, network, or addon work.

Dismiss, pop, and quit **own** in-flight work: cancel the search `Task`, remove `NSEvent` monitors (`hide()` already stops click-outside), `terminate()` the addon `Process`, run declared `cleanup`. `Task.detached` in `runInvocation` is not fire-and-forget across a dismiss. Hold work with `[weak self]` / weak host; do not capture `AppDelegate` strongly in HotKey or monitor callbacks.

## Types and errors

- Prefer `struct` / `enum`, `Equatable`, `Sendable`, explicit `Codable`.
- Protocol models (`RunRequest`, `RunResponse`, `UIDescriptor`) are `api: 1` — additive only. The toast shape `{ "ok": true, "message": "…" }` is forever.
- Typed `*Error` / `*Failure` enums in Core. User copy only through `UserFacingError.message(for:)`. Never surface YAML paths, stack traces, or “addon exited 1”.
- `try?` is allowed for best-effort config/state/cache writes only — never for runner, install, checksum, or protocol decode.
- No force unwraps or force casts in product code. In tests use `XCTUnwrap` or `Data(string.utf8)`, not `!` / `as!`.
- Make illegal states unrepresentable: `ShellPreset` / stack entries, not `isCatalogOpen && !isSettings`. Two booleans that can both be true are a bug.

## Naming

If a comment would say **what** the code does, the name is wrong. Rename; do not comment.

- Functions are verbs of the outcome: `popTop`, `goHome`, `markFirstPaint` — not `handleEsc`, `doProcess`, `processData`.
- Types are the job: `CommandIndex`, `AddonRunner` — not `Manager`, `Helper`, `Util`, `Handler`.
- Booleans are predicates: `isAtRoot`, `isVisible` — not `flag`, `status`, `mode`.
- Swift types / members: PascalCase / camelCase. YAML / JSON keys: `snake_case` via `CodingKeys`.
- Tests: `test_pushSamePreset_isIdempotent_updatesTopInPlace` (behavior), not `testStack1`.

## Comments

Default is **no comment**. A comment is allowed only when the **why** is surprising and the names cannot carry it (0.8 s timeout, `try?` on a cache write, click-outside is dismiss not pop).

If you need one, it is a **single** `//` line on the surprising line. No `/* */`, no `/** */`, no `///`, no stacked `//` paragraphs, no file banners, no `// MARK:` as a table of contents. Do not comment what, who, how, or the plan. Do not comment out code. Do not add `TODO`/`FIXME` — use `docs/tickets.md`. Architecture belongs in this file or `docs/architecture/`, not above a method. Tests and names carry the **what**.

## Unnecessary and smelly code

Lint will not catch a second `ShellHost`. These are the extra fences:

- **Delete, don’t park.** Unused functions, unused `public`, empty `default: break` waiting for a future preset, `#if false`, and duplicate hosts are defects. Prefer a failing test over a commented stub.
- **One implementation per job.** If you are replacing `UIHostController` with `ShellHost`, finish the cut in the same slice or leave a ticket — do not ship both as “real.”
- **Size is a smell signal, not a style contest.** SwiftLint already warns on long files/functions/complexity. A 200-line `switch` on hotkey names is fine (`ignores_case_statements`). A 200-line view that also talks to `Process` is not — split by layer, not by “extract method” fashion.
- **No speculative abstraction.** Protocols only at FS / process / clock / network / clipboard boundaries (and view-model protocols the UI already uses). Do not add wrappers “for testability” when `JugnuPaths(home:)` already injects.
- **JugnuUI must not spawn work the Core runner owns.** `Process(`, `URLSession`, and `UserDefaults` in `shell/Sources/JugnuUI` are errors (custom SwiftLint). Put them in Core or App.

## Hygiene (CI owns this)

Reviewers should not spend time on unused locals, unused imports, or force unwraps. SwiftLint must fail locally and in CI:

- Install/run: `make tools-swift` then `make lint-swift`. Pre-commit runs SwiftLint on staged `.swift` files.
- `force_unwrapping`, `force_cast`, `force_try` are **errors** in product code. Tests may use `XCTUnwrap` / `Data(string.utf8)` instead of `!`.
- Prefer the compiler’s unused-value warnings; do not land them.
- `unused_declaration` / `unused_import` analyzer rules need `swiftlint analyze` (compiler log). They are not the CI `swiftlint lint` path yet — do not leave dead types sitting because lint was quiet.

Do not add SwiftLint rules that try to judge algorithms. Wrong structure on the hot path is a conventions/review miss, not a linter miss.

## UI ownership

One `KeyablePanel`. Destinations are named presets (`launcher`, `catalog`, `settings`, `detail`, `confirm`, `list`, `form`). Frame size is a **view type** from the [viewport catalog](architecture/2026-08-24-view-types.md), not addon yaml. Toast is a HUD, not a stack node. `note` is the only detached window class in v1. Details: [shell surface presets](architecture/2026-08-23-shell-surface-presets.md).

| Shell owns | Addon owns |
|---|---|
| Windows, focus, Esc / pop / home / click-out | Job logic and system calls |
| Pattern layouts, `JugnuTokens`, theme | Which pattern + JSON fields |
| View-type size/aspect (current screen `visibleFrame` + clamps) | Which view-type **ids** are allowed; which id this command uses |
| Motion (~200 ms morph; Reduce Motion snaps) | `cleanup.paths` / `cleanup.launchd` |
| Latency measurement | Tiny entrypoint that returns JSON |

Addons never create `NSWindow` and never declare pixel sizes or percents. They declare `view_types: [id, …]` from the catalog. Use the smallest type that finishes the job. Nested navigation stays inside the stack (push child, replace sibling, pop restores view state). Leaving a long job cancels the process and runs cleanup.

Click-outside **dismisses** `seek` / `palette` / `ask` / `fields` / `rows` / `grid` / `rail`. It does **not** dismiss `board` / `spread` / `canvas` (Esc / Cmd+W).

Window geometry addons (`window-layouts`) request Accessibility **on first use**, keep tiling on AX, and isolate private CGS. Do not disable SIP. Do not add `layout-undo`. Spec: [window-layouts](architecture/2026-08-24-window-layouts.md).

Do not use SwiftUI `.sheet`, `.alert`, `.confirmationDialog`, or `NavigationStack` in the shell panel. Those are extra windows and a second navigation model. Confirm/list/form are stack presets; toast is the HUD.

**Focus:** first arrival at a preset focuses that preset’s default (search on `launcher`/`catalog`/`list`, Confirm on `confirm`, first field on `form`). Pop restores the previous first responder. Toast must not steal search focus. Invoke must key the panel on the first press.

## Addon contract

Canonical: [ADR 0001](architecture/decisions/0001-json-addon-boundary.md), [addon-manifest.md](addon-manifest.md).

- Out-of-process JSON on stdin/stdout. Entrypoint kinds: `exec`, `jxa`, `osascript`.
- One zip unpacks to `~/.local/share/jugnu/addons/<id>/`. **Never inside `Jugnu.app`.**
- Published addons must not require user-installed Python or Homebrew.
- Stdout is **one JSON object**. Logs go to stderr, and stay quiet.
- Declare `cleanup` for every side effect. Disable/uninstall must be deterministic.
- Entrypoint path is relative, no `..`.
- Follow-ups: same entrypoint, richer `args` — not a second IPC model.
- `apps/` and `extensions/macos/` are staging only. Do not scaffold an addon until its packaging boundary is explicit.

## Testing

Tests carry the **what** that comments must not. `test_pop_atRoot_isNoOp` is the spec; a comment on the test is noise.

- TDD for `JugnuCore` at boundaries: YAML/JSON, paths, index, fuzzy, runner fixtures, checksum, cleanup. Use temp `JugnuPaths(home:)`.
- Assert the outcome (`stack.top.preset == .catalog`, timeout error, toast ceiling), not the implementation (mock call counts, private state).
- One behavior per test. The name is the sentence.
- `JugnuUITests` cover stack/preset math, not live `NSPanel`. AppKit-visible changes still need [shell-smoke.md](architecture/shell-smoke.md).
- Live registry/install tests stay in `shell/TestsExtended/` (`make test-extended`). Never in CI. Never the only coverage for a Core behavior.
- Do not make Linux or CI tests require `osascript`, `pbcopy`, `pmset`, or `shortcuts`.
- If you touch invoke, runner, search, or first paint, add a test that would fail if that work moved back onto MainActor or onto the hot path.
- Do not add tests that only lock today’s private structure so a rename fails. That is the testing equivalent of a what-comment.

## Compatibility and logs

- `api: 1` and `jugnu.yaml` are **additive**. New fields are optional with defaults. Do not rename, reuse, or change the meaning of an existing key (`ok`, `message`, `theme`, reserved `ui`, command ids).
- Logs are `InvokeTrace` timings/ids or a user-facing `UserFacingError`. No `print`/`NSLog` of JSON, paths, clipboard, or args. `#if DEBUG` trace print is the ceiling for invoke spam.

## Privacy and trust

See [PRIVACY.md](../PRIVACY.md).

- No clipboard, credentials, tokens, or file contents in logs.
- `context` stays empty in v1 — no screen pixels, no concealed pasteboard. Context-aware behavior is later, opt-in, and local.
- SHA-256 via CryptoKit. New unzip/install code must reject path traversal (ticket 0003 is known debt; do not copy it).
- Cleanup only declared addon-owned paths and launchd labels. The manifest is the trust boundary.
- Permissions at point of use, with a usable fallback.

## Do not revive

Locked by ADR 0001 and the UI/speed spec:

- In-process plugin loading
- HTML/JS WebView as the default addon UI
- SwiftUI bundles loaded from zips
- Addons bundled inside `Jugnu.app`
- Per-addon width/height in yaml
- A second unmanaged `NSWindow` for catalog, prefs, or addon UI
- User-installed Python or Homebrew for published addons

## Reviewer watchlist

What a junior PR still gets wrong after the rules above. Reject these:

- **`default: break` on `ShellPreset` / `UIPattern`.** New destinations must not vanish. Exhaustive `switch` or a compile error.
- **New `*Error` case not in `UserFacingError`.** The toast becomes “Something went wrong.”
- **Empty `catch` / ignored `Task` failure.** Allowed `try?` is only config/state/cache writes.
- **`public` so a test can see it.** App stays internal; tests use `@testable import`.
- **Magic size or `Color.accentColor`.** View-type size table / `ShellPreset.size` and `JugnuTokens` / theme only. No per-addon width/height.
- **`NSScreen.main` for a morph** when the panel already has `currentScreen` (multi-display).
- **`DispatchQueue.main.async` from `@MainActor`** on the invoke path — extra frame, blows the 50 ms budget. HotKey’s callback is the exception (it is not MainActor).
- **`List`/`ForEach` without a stable id** (`qualifiedId`, addon id). No `id: \.offset`, no `.id(UUID())` on the palette.
- **`onTapGesture` on a card that also has buttons.** Clicks never hit Install (see 0006).
- **Tests that use the real home, `Date()`, or the network** in `JugnuCoreTests`. `JugnuPaths(home: temp)`, inject `now`, live calls only in `TestsExtended`.
- **`refreshIndex()` / YAML / directory walk inside invoke.** Already forbidden on the hot path; it still shows up in `AppDelegate` “just to be safe.”
- **A view that must update but does not observe the model** (enable/disable/install). Mutating `AppModel` is not enough if the catalog VM never reads it.
- **`.sheet` / `.alert` / `NavigationStack` in the panel.** Stack presets and the toast HUD only.
- **Focus left on the wrong control** after push/pop, or toast becoming key.
- **`///`, `/* */`, or a comment block** on a type or method. One `//` why, or nothing.
- **New fact in the wrong home.** `UserDefaults`, `static var`, untyped yaml, or extra fields on the theme paint bus.

## Review checklist

Use on every Swift or addon change. If any row is no, the change is not done.

| Check | Pass looks like |
|---|---|
| Reuse | Named the existing type, or the PR says why it is wrong |
| Layer | New type sits in Core, UI, or App for the right reason |
| Data | Law / config / state / call — not a new singleton or `UserDefaults` |
| Hot path | No FS / network / Process / index rebuild before first paint |
| Chrome | Known panel jobs skeleton within 100 ms; toast stays HUD |
| MainActor | UI mutations only; runner work is detached |
| Errors | Typed error in Core; `UserFacingError` at the toast/banner |
| Windows | Still one `KeyablePanel`; no new `NSWindow` from an addon |
| Addon | JSON in/out, tiny exec, cleanup declared, not in the `.app` |
| Lifetime | Dismiss/pop/quit cancels Tasks, monitors, and addon processes |
| Compat | YAML / `api: 1` additive; no key reuse |
| Privacy | No secrets in logs; `context` still empty unless designed |
| Hygiene | SwiftLint clean; no new `!` / `as!` / `try!` in product code |
| Names | A reader does not need a what-comment |
| Comments | Absent, or one `//` why |
| Tests | Named behavior; would fail if the outcome changed |
| Watchlist | No `default: break` on presets; no magic colors/sizes; no real `$HOME` in unit tests |
