# Palette + Addon UI Product Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Jugnu’s palette and addon UI host feel like one native, themeable, keyboard-first product — fuzzy search, shared tokens, SwiftUI panels, live theme push — without adding new addon jobs or Preferences/catalog scope.

**Architecture:** `JugnuCore` owns config (`theme` / `sound` / `palette`), fuzzy `CommandIndex.search`, runner wait-without-poll, hotkey parse, and user-facing error strings. `JugnuUI` owns tokens, presets, environment theme, and SwiftUI-hosted panels (same `NSPanel` public inits as today). `App/` owns palette chrome, first-run, prefs theme section, icon, and reactive `AppModel` publishing. Live registry tests live in a separate SPM package (`shell/TestsExtended`) that default `swift test` / CI must not run.

**Tech Stack:** macOS 14+, Swift 5.9+, JugnuCore + JugnuUI + Jugnu app (SPM), Yams, HotKey, SwiftUI hosted in `NSPanel`, XCTest.

**Spec:** [docs/architecture/2026-08-23-palette-ui-product-pass.md](../../architecture/2026-08-23-palette-ui-product-pass.md)

**Scope note:** This stays **one plan**. Theming is a hard dependency of every visual surface; splitting A/B/D into separately shippable plans would leave half-themed chrome. Sequence: Core config + search + runner → tokens/theme → AppModel → palette and panels (panels may proceed panel-by-panel once tokens exist) → prefs/icon/live tests/docs.

## Global Constraints

- Work on the **current checkout**. Do not create branches, worktrees, or commits unless the user explicitly asks in that session (repo `AGENTS.md`).
- Prefer TDD on `JugnuCore`. Watch each new test fail before implementing. UI tasks: smallest Core/logic test possible, then manual macOS check.
- Copy tone: **warm but restrained** — plain sentences, no jokes, no raw `ManifestLoaderError.emptyId` (or `String(describing:)`) in the UI.
- Do **not** wire new real addons to confirm/list/form. `floating-note` (`note`) and `clipboard-history` (already declares `ui.pattern: list`) must keep working after the rewrite.
- Do **not** implement tickets 0001–0003, VoiceOver labels, shaped skeleton placeholders, `progress`/`status` patterns, or menu-bar trail animation wiring (design-only until P2).
- Published addons: no user Python. Shell binary still ships **no** addon payloads.
- Invalid theme hex → built-in default for **that field only**; never crash.
- `ui: [String: String]` stays reserved and unused. Theme is a sibling `theme:` key.
- Reduce Motion: skip glow-bloom; skip panel/toast motion; freeze any icon animation (when it exists).
- Terminal Phosphor preset uses **SF Mono** for UI type; Firefly and Rose Quartz keep SF Pro / Dynamic Type styles.

---

## File map

```
shell/Sources/JugnuCore/
  Models.swift                 # ThemeConfig, JugnuTheme, PaletteConfig, sound, recommended IDs
  Fuzzy.swift                  # subsequence match + score (new)
  CommandIndex.swift           # tiered fuzzy search + closestMatch
  AddonRunner.swift            # terminationHandler / DispatchGroup wait (no 50ms poll)
  HotkeySpec.swift             # parse "option+space" → key + modifiers (new)
  UserFacingError.swift        # Error → user string (new)
  StateStore.swift             # recentCommandIDs, favoriteCommandIDs
  ConfigStore.swift            # decode new keys with defaults (likely no API change)

shell/Sources/JugnuUI/
  DesignTokens.swift           # radius / spacing / typography (new)
  Theme.swift                  # presets, Color(hex), environment key (new)
  KeyablePanel.swift           # moved from App/; canBecomeKey (new path)
  PanelErrorBanner.swift       # shared inline error (new)
  ToastPresenter.swift         # rewrite → SwiftUI in NSPanel
  ConfirmPanel.swift           # rewrite → borderless SwiftUI
  ListPanel.swift              # rewrite → borderless SwiftUI + filter
  FormPanel.swift              # rewrite → borderless SwiftUI
  SkeletonPanel.swift          # rewrite → borderless "Loading {pattern}…"
  NotePanel.swift              # rewrite → titled SwiftUI TextEditor
  UIHostController.swift       # inline errors; no toast-on-follow-up-fail
  CommandInvoke.swift          # play success/error sound via injected hook

shell/App/
  PalettePanelController.swift # cursor screen, fade, reset, debounce, tokens
  AppModel.swift               # @Published resolvedTheme, firstView data, sounds
  PrefsView.swift              # sectioned Addons / Theme / Sound
  FirstRunWindow.swift         # recommendedLocalRoots uses ShellConfig.recommendedAddonIDs
  HotkeyController.swift       # call HotkeySpec.parse
  MenuBarController.swift      # template status-item image
  Info.plist                   # CFBundleIconName if needed
  Assets.xcassets/AppIcon.appiconset/   # generated PNGs
  Assets.xcassets/MenuBarIcon.imageset/ # template PNG

shell/Tests/JugnuCoreTests/
  ThemeConfigTests.swift       # new
  FuzzyTests.swift             # new
  CommandIndexTests.swift      # extend
  AddonRunnerTests.swift       # extend (fast-exit fixture)
  HotkeySpecTests.swift        # new
  UserFacingErrorTests.swift   # new
  ConfigStoreTests.swift       # extend
  Fixtures/sample-config.yaml  # add theme/sound/palette

shell/TestsExtended/              # separate package — never in default swift test / CI
  Tests/JugnuCoreLiveTests/RegistryLiveTests.swift

shell/Package.swift            # JugnuCoreTests only (default / CI)
.github/workflows/ci.yml       # swift test (no filter)
Makefile                       # test-extended
config/jugnu.example.yaml
shell/README.md
docs/architecture/shell-smoke.md
docs/ideas.md                  # shaped-skeleton fast-follow
CHANGELOG.md
```

### Locked product values (copy verbatim)

**Recommended first-run set** (curated, not all 11):

```swift
public static let recommendedAddonIDs = [
    "mic-mute", "focus-toggle", "paste-plain", "floating-note", "ports",
]
```

Keep the original three day-one jobs; add `floating-note` (already on the `note` host) and `ports` (representative of the graduated set). Skip `clipboard-history` on first-run (launchd watcher is a heavy side effect; live tests cover it). Skip battery / weather / world-clock / pomodoro / brew-outdated as later installs.

**Firefly (default) / Terminal Phosphor / Rose Quartz** hex tables: spec §3. `error` is always `#E5484D`.

**Search debounce:** 100 ms (midpoint of spec 80–120 ms).

**Palette fade:** 120 ms; glow-bloom skipped when Reduce Motion is on.

**Recent list length:** 8 qualified ids, recorded only while `palette.firstView == .recent`.

**Sounds:** `NSSound(named: "Tink")` on success, `NSSound(named: "Basso")` on error; gated on `config.sound` (default `true`).

**Empty-addon copy:** `No addons yet — install some to get started.`

**Placeholder (addons exist, blank first view):** rotate `Try ‘\(hint)’…` where `hint` is `keywords.first ?? title.split(separator: " ").prefix(2).joined(separator: " ")`.

**Did-you-mean row subtitle:** `Did you mean this?`

---

### Task 1: Config — `theme`, `sound`, `palette`

**Files:**
- Modify: `shell/Sources/JugnuCore/Models.swift`
- Modify: `shell/Tests/JugnuCoreTests/ConfigStoreTests.swift`
- Modify: `shell/Tests/JugnuCoreTests/Fixtures/sample-config.yaml`
- Create: `shell/Tests/JugnuCoreTests/ThemeConfigTests.swift`

**Interfaces:**
- Produces:
  - `public struct JugnuTheme: Codable, Equatable, Sendable` — `accent`, `background`, `surface`, `textPrimary`, `textSecondary`, `error` as `String` (hex). CodingKeys: `accent`, `background`, `surface`, `text_primary`, `text_secondary`, `error`.
  - `public struct ThemeConfig: Codable, Equatable, Sendable` — `light: JugnuTheme`, `dark: JugnuTheme`. Static `firefly` defaults from spec §3.
  - `public enum PaletteFirstView: String, Codable, Sendable` — `blank`, `recent`, `favorites`
  - `public struct PaletteConfig: Codable, Equatable, Sendable` — `firstView: PaletteFirstView` (YAML `first_view`)
  - `JugnuConfig` gains `theme: ThemeConfig`, `sound: Bool`, `palette: PaletteConfig`; keep `ui`. Defaults: Firefly, `sound: true`, `firstView: .blank`.
  - `JugnuTheme.sanitized(against defaults: JugnuTheme) -> JugnuTheme` — per-field: if value does not match `#` + 6 hex digits (case-insensitive), replace with that field from `defaults`.

- [x] **Step 1: Write failing tests**

```swift
final class ThemeConfigTests: XCTestCase {
    func testDefaultThemeIsFireflyDarkAccent() {
        XCTAssertEqual(ThemeConfig.firefly.dark.accent, "#F5A623")
        XCTAssertEqual(ThemeConfig.firefly.light.background, "#F7F3EA")
        XCTAssertEqual(ThemeConfig.firefly.dark.error, "#E5484D")
    }

    func testSanitizeInvalidHexUsesDefaultForThatFieldOnly() {
        var dirty = ThemeConfig.firefly.dark
        dirty.accent = "not-a-color"
        dirty.background = "#16130E"
        let clean = dirty.sanitized(against: ThemeConfig.firefly.dark)
        XCTAssertEqual(clean.accent, "#F5A623")
        XCTAssertEqual(clean.background, "#16130E")
    }

    func testJugnuConfigDecodesMissingThemeAsFirefly() throws {
        let yaml = "version: 1\nshell:\n  hotkey: option+space\naddons: {}\n"
        let config = try YAMLDecoder().decode(JugnuConfig.self, from: yaml)
        XCTAssertEqual(config.theme, .firefly)
        XCTAssertEqual(config.sound, true)
        XCTAssertEqual(config.palette.firstView, .blank)
        XCTAssertEqual(config.ui, [:])
    }
}
```

Also extend `ConfigStoreTests.testLoadMissingCreatesDefaults` to assert `theme.dark.accent == "#F5A623"` and `sound == true`. Extend `testLoadSampleFixture` after adding optional keys to the fixture (fixture may omit them; decode defaults).

- [x] **Step 2: Run to verify fail**

Run: `cd shell && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift test --filter ThemeConfigTests`

Expected: FAIL (types missing).

- [x] **Step 3: Implement types on `JugnuConfig`**

Add structs above. Custom `init(from:)` on `JugnuConfig` using `decodeIfPresent` for `theme`, `sound`, `palette` (and existing fields). Encode with `theme`, `sound`, `palette.first_view`. Do not put theme into `ui`.

```swift
public func sanitized(against defaults: JugnuTheme) -> JugnuTheme {
    func hex(_ value: String, _ fallback: String) -> String {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = t.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
        return ok ? t : fallback
    }
    return JugnuTheme(
        accent: hex(accent, defaults.accent),
        background: hex(background, defaults.background),
        surface: hex(surface, defaults.surface),
        textPrimary: hex(textPrimary, defaults.textPrimary),
        textSecondary: hex(textSecondary, defaults.textSecondary),
        error: hex(error, defaults.error)
    )
}
```

- [x] **Step 4: Run to verify pass**

Run: `cd shell && swift test --filter ThemeConfigTests --filter ConfigStoreTests`

Expected: PASS.

- [x] **Step 5: Commit** — skip unless the user asked.

---

### Task 2: User-facing error strings

**Files:**
- Create: `shell/Sources/JugnuCore/UserFacingError.swift`
- Create: `shell/Tests/JugnuCoreTests/UserFacingErrorTests.swift`

**Interfaces:**
- Produces: `public enum UserFacingError` with `public static func message(for error: Error) -> String`

Exact strings:

| Error | Message |
|---|---|
| `ManifestLoaderError.emptyId` | `This addon is missing its name. Try reinstalling it.` |
| `ManifestLoaderError.invalidEncoding` | `This addon’s description couldn’t be read. Try reinstalling it.` |
| `ManifestLoaderError.unsupportedAPI` | `This addon needs a newer Jugnu.` |
| `AddonRunnerError.timeout` | `That took too long. Try again.` |
| `AddonRunnerError.invalidResponse` | `The addon didn’t return a result we could use.` |
| `AddonRunnerError.unsupportedEntrypointKind` | `This addon can’t run on this Mac.` |
| `AddonInstallerError.sha256Mismatch` | `The download didn’t match what we expected. Nothing was installed.` |
| `AddonInstallerError.missingURL` | `No download location is listed for this addon.` |
| anything else | `Something went wrong. Try again.` |

- [x] **Step 1: Failing tests**

```swift
func testEmptyIdNeverLeaksEnumName() {
    let msg = UserFacingError.message(for: ManifestLoaderError.emptyId)
    XCTAssertEqual(msg, "This addon is missing its name. Try reinstalling it.")
    XCTAssertFalse(msg.contains("emptyId"))
    XCTAssertFalse(msg.contains("ManifestLoader"))
}
```

- [x] **Step 2: Run — FAIL** (`swift test --filter UserFacingErrorTests`)
- [x] **Step 3: Implement `UserFacingError.message(for:)`** with a switch on known types; default generic string.
- [x] **Step 4: Run — PASS**
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 3: Fuzzy subsequence search + did-you-mean

**Files:**
- Create: `shell/Sources/JugnuCore/Fuzzy.swift`
- Create: `shell/Tests/JugnuCoreTests/FuzzyTests.swift`
- Modify: `shell/Sources/JugnuCore/CommandIndex.swift`
- Modify: `shell/Tests/JugnuCoreTests/CommandIndexTests.swift`

**Interfaces:**
- Consumes: `IndexedCommand` fields `title`, `keywords`, `subtitle`
- Produces:
  - `public enum SearchTier: Int, Comparable, Sendable` — `title = 0`, `keyword = 1`, `subtitle = 2`
  - `public struct SearchHit: Equatable, Sendable` — `command: IndexedCommand`, `tier: SearchTier`, `score: Int`, `isSuggestion: Bool`
  - `public enum Fuzzy` — `static func score(query: String, in text: String) -> Int` (0 = not a subsequence)
  - `CommandIndex.replaceCommandsForTesting(_ commands: [IndexedCommand])` — test-only (`#if DEBUG` not required; used from `@testable`). Replaces the private `commands` array.
  - `CommandIndex.search(_ query: String) -> [IndexedCommand]` — empty query returns `all` (alpha title, unchanged). Non-empty: hits with `score > 0`, sort by tier ascending, then score descending, then title A–Z. **Normal cutoff:** `score > 0`.
  - `CommandIndex.searchHits(_ query: String) -> [SearchHit]` — same ranking; when non-empty query yields zero hits, append **exactly one** `SearchHit` with `isSuggestion: true` for the command with the highest `score` treating unmatched as `0` and breaking ties by smallest `Fuzzy.editDistance(query, title)`; if every score is 0, pick min edit distance on `title` (then A–Z).
  - Keep `search(_:)` returning `[IndexedCommand]` for AppModel; implement it as `searchHits(query).map(\.command)`.

**Scoring (locked):** lowercase both; ignore characters other than `[a-z0-9]` in query and text (so `mcmt` vs `Mic Mute` works). Walk text in order; each query char must appear. Score starts at 0; `+4` for a consecutive match, `+8` if the match is at index 0 or after a skipped-separator boundary, else `+1`. If the query is not a full subsequence, return `0`.

`editDistance` is standard Levenshtein on the already-normalized strings; used only for the zero-hit suggestion fallback.

- [x] **Step 1: Failing tests**

```swift
func testMcmtMatchesMicMuteTitle() {
    XCTAssertGreaterThan(Fuzzy.score(query: "mcmt", in: "Mic Mute"), 0)
    XCTAssertEqual(Fuzzy.score(query: "zzzz", in: "Mic Mute"), 0)
}

func testTitleTierBeatsKeywordEvenIfKeywordScoreHigher() {
    let zoom = IndexedCommand(
        addonId: "a", commandId: "z", title: "Zoom", subtitle: "",
        keywords: ["mic mute"], addonRoot: URL(fileURLWithPath: "/tmp")
    )
    let mute = IndexedCommand(
        addonId: "b", commandId: "t", title: "Mic Mute", subtitle: "",
        keywords: [], addonRoot: URL(fileURLWithPath: "/tmp")
    )
    var index = CommandIndex(paths: JugnuPaths(home: URL(fileURLWithPath: "/tmp")), config: JugnuConfig())
    index.replaceCommandsForTesting([zoom, mute])
    XCTAssertEqual(index.search("mcmt").first?.title, "Mic Mute")
}

func testEmptyQueryReturnsAllAlphabetical() { /* existing behavior */ }

func testZeroHitsReturnsSingleSuggestion() {
    let hits = index.searchHits("nope")
    XCTAssertEqual(hits.count, 1)
    XCTAssertTrue(hits[0].isSuggestion)
}
```

Keep existing `testEnabledAppearsDisabledOmittedAndSearchFilters` passing: `search("mic")` still finds mic-mute; `search("")` still returns all.

- [x] **Step 2: Run — FAIL** (`swift test --filter FuzzyTests --filter CommandIndexTests`)
- [x] **Step 3: Implement `Fuzzy` + replace substring `filter` in `CommandIndex.search`**
- [x] **Step 4: Run — PASS**
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 4: AddonRunner — wait on termination, not a 50 ms poll

**Files:**
- Modify: `shell/Sources/JugnuCore/AddonRunner.swift`
- Modify: `shell/Tests/JugnuCoreTests/AddonRunnerTests.swift`
- Create fixture if needed: `shell/Tests/JugnuCoreTests/Fixtures/echo-addon/bin/run` already exists

**Interfaces:**
- Consumes: existing sync `run(...) throws -> RunResponse`
- Produces: same signature. Internally: set `process.terminationHandler` to leave a `DispatchGroup` (or `NSCondition`); `wait` with `timeout`; if still running, `terminate()` and throw `.timeout`. **No** `Thread.sleep` loop.

- [x] **Step 1: Failing test** — add `testFastEchoDoesNotNeedFullTimeoutWindow` that records `Date()` around `run` of the echo fixture with `timeoutSeconds: 2` and asserts elapsed `< 0.4` (today a lucky fast process can already pass; the implementation change is still required). Stronger: read `AddonRunner.swift` in review and reject if `Thread.sleep` remains.

```swift
func testEchoCompletesWellUnderTimeout() throws {
    let start = Date()
    _ = try AddonRunner(timeoutSeconds: 2).run(manifest: manifest, addonRoot: work, commandId: "ping")
    XCTAssertLessThan(Date().timeIntervalSince(start), 0.4)
}
```

- [x] **Step 2: Run** — may already pass on elapsed time; **must** still replace the poll (spec: real bug, not optional).
- [x] **Step 3: Replace the `while process.isRunning` loop**

```swift
let group = DispatchGroup()
group.enter()
process.terminationHandler = { _ in group.leave() }
try process.run()
stdin.fileHandleForWriting.write(requestData)
try stdin.fileHandleForWriting.close()
let waited = group.wait(timeout: .now() + timeout)
if waited == .timedOut {
    process.terminate()
    _ = group.wait(timeout: .now() + 1)
    throw AddonRunnerError.timeout
}
```

Guard against `terminationHandler` firing before `wait` (enter before `run`).

- [x] **Step 4: Run `swift test --filter AddonRunnerTests` — PASS; grep confirms no `sleep(forTimeInterval: 0.05)`**
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 5: Hotkey string parse in Core

**Files:**
- Create: `shell/Sources/JugnuCore/HotkeySpec.swift`
- Create: `shell/Tests/JugnuCoreTests/HotkeySpecTests.swift`
- Modify: `shell/App/HotkeyController.swift`

**Interfaces:**
- Produces: `public struct HotkeySpec: Equatable, Sendable` — `key: String` (canonical: `space`, `a`…`z`, `return`, `tab`, `escape`), `modifiers: Set<String>` (canonical: `command`, `option`, `control`, `shift`). `public static func parse(_ raw: String) -> HotkeySpec?`
- Accept aliases: `cmd`/`command`, `opt`/`option`/`alt`, `ctrl`/`control`, `esc`/`escape`, `enter`/`return`.
- `HotkeyController.parse` becomes a thin map from `HotkeySpec` → `KeyCombo`. Tests live in Core so they do not need the HotKey package.

- [x] **Step 1: Failing tests**

```swift
func testOptionSpace() {
    let spec = try XCTUnwrap(HotkeySpec.parse("option+space"))
    XCTAssertEqual(spec.key, "space")
    XCTAssertEqual(spec.modifiers, ["option"])
}

func testCmdSpaceAliases() {
    XCTAssertEqual(HotkeySpec.parse("cmd+space"), HotkeySpec.parse("command+space"))
}

func testUnknownKeyIsNil() {
    XCTAssertNil(HotkeySpec.parse("option+f13x"))
}
```

- [x] **Step 2: Run — FAIL**
- [x] **Step 3: Implement parse (move logic from `HotkeyController`); HotkeyController uses `HotkeySpec.parse` then maps to `Key` / `NSEvent.ModifierFlags`**
- [x] **Step 4: Run — PASS** (`swift test --filter HotkeySpecTests`)
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 6: Recommended addon IDs — one source of truth

**Files:**
- Modify: `shell/Sources/JugnuCore/Models.swift` (`ShellConfig.recommendedAddonIDs`)
- Modify: `shell/App/FirstRunWindow.swift`
- Create: `shell/Tests/JugnuCoreTests/RecommendedAddonsTests.swift` (assert the locked list)

**Interfaces:**
- Produces: `recommendedAddonIDs` = `["mic-mute", "focus-toggle", "paste-plain", "floating-note", "ports"]`
- `FirstRunWindow.recommendedLocalRoots()` **must** iterate `ShellConfig.recommendedAddonIDs` — no local string array.

- [x] **Step 1: Failing test**

```swift
func testRecommendedSetIsTheCuratedFive() {
    XCTAssertEqual(
        ShellConfig.recommendedAddonIDs,
        ["mic-mute", "focus-toggle", "paste-plain", "floating-note", "ports"]
    )
}
```

- [x] **Step 2: Run — FAIL** (still the old three)
- [x] **Step 3: Update the static list; change `let ids = ["mic-mute", …]` to `let ids = ShellConfig.recommendedAddonIDs`**
- [x] **Step 4: Run — PASS**
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 7: State — recent + favorites

**Files:**
- Modify: `shell/Sources/JugnuCore/StateStore.swift`
- Create: `shell/Tests/JugnuCoreTests/StateStoreTests.swift` (create if missing)

**Interfaces:**
- `JugnuState` gains `recentCommandIDs: [String]` and `favoriteCommandIDs: [String]` (qualified ids). Decode missing as `[]`.
- `mutating func recordRecent(qualifiedId: String, limit: Int = 8)` — move-to-front, unique, cap `limit`.
- `mutating func toggleFavorite(qualifiedId: String)` — add or remove.

- [x] **Step 1: Failing tests** for decode-defaults, move-to-front, cap 8, toggle favorite.
- [x] **Step 2: Run — FAIL**
- [x] **Step 3: Implement**
- [x] **Step 4: Run — PASS**
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 8: JugnuUI tokens, presets, environment theme

**Files:**
- Create: `shell/Sources/JugnuUI/DesignTokens.swift`
- Create: `shell/Sources/JugnuUI/Theme.swift`
- Create: `shell/Sources/JugnuUI/KeyablePanel.swift` (move `KeyablePanel` out of `PalettePanelController.swift`)
- Modify: `shell/App/PalettePanelController.swift` (import; delete local `KeyablePanel`)

**Interfaces:**
- Consumes: `JugnuTheme`, `ThemeConfig` from Core
- Produces:
  - `public enum JugnuTokens` — `Radius.panel = 12`, `Spacing.panelPadding = 14`, `Spacing.row = 8`, `Typography.title = Font.headline`, `Typography.body = Font.body`, `Typography.caption = Font.caption`
  - `public enum JugnuPresets` — `firefly`, `terminalPhosphor`, `roseQuartz` as `ThemeConfig` with **exact hex from spec §3**; `public static let all: [(id: String, name: String, config: ThemeConfig)]` in display order Firefly, Terminal Phosphor, Rose Quartz
  - `public struct JugnuThemeColors` — `Color` properties resolved from sanitized hex
  - `private struct ThemeEnvKey: EnvironmentKey` default Firefly dark
  - `extension EnvironmentValues { public var jugnuTheme: JugnuThemeColors }`
  - `extension Color { init(jugnuHex: String, fallback: Color) }`
  - `public func resolvedTheme(from config: ThemeConfig, colorScheme: ColorScheme) -> JugnuTheme` — pick light/dark, then `sanitized(against:)` the matching Firefly mode

**Phosphor type:** `JugnuTokens.font(for presetId: String, role:)` returns `.system(.body, design: .monospaced)` when preset is Terminal Phosphor; otherwise Dynamic Type styles.

App cannot unit-test SwiftUI environment easily; Core already tested sanitization. After this task, `PaletteView` may still use system colors until Task 10 — that is OK.

- [x] **Step 1:** No Core test required. Manually confirm `JugnuPresets.terminalPhosphor.dark.accent == "#39FF6A"` in a tiny `JugnuUI` test **only if** you add a `JugnuUITests` target; otherwise add `testPhosphorAccent()` next to ThemeConfigTests by putting preset hex constants on `ThemeConfig` in Core:

**Ruling (plan-locked):** preset data lives in **Core** as `ThemeConfig.firefly`, `.terminalPhosphor`, `.roseQuartz` so tests do not need a UI target. `JugnuUI.JugnuPresets` is a typealias/wrapper over those statics plus display names.

Add to Task 1 types if not already there:

```swift
extension ThemeConfig {
    public static let terminalPhosphor = ThemeConfig(light: …, dark: …) // spec table
    public static let roseQuartz = ThemeConfig(light: …, dark: …)
}
```

If Task 1 already shipped only Firefly, add Phosphor/Rose Quartz tests here (`swift test --filter ThemeConfigTests`).

- [x] **Step 2–4:** Implement tokens + environment + move `KeyablePanel`. `swift test` still green.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 9: AppModel — reactive theme, search hits, first-view data, errors

**Files:**
- Modify: `shell/App/AppModel.swift`
- Modify: `shell/Sources/JugnuUI/CommandInvoke.swift` (optional sound callback)

**Interfaces:**
- Consumes: Tasks 1–3, 7–8
- Produces:
  - `@Published var config` already exists; after every `store.save` assign `self.config = saved` (do not only mutate a copy).
  - `func resolvedTheme(colorScheme: ColorScheme) -> JugnuTheme` using `config.theme` + sanitize.
  - `func search(_ query: String) -> [IndexedCommand]` uses `index.searchHits`; stash `var lastHits: [SearchHit]` so the palette can mark the suggestion row.
  - `func commandsForFirstView() -> [IndexedCommand]` — `blank` → `[]` (placeholder handles empty query); `recent` → lookup `state.recentCommandIDs` in `index.all`; `favorites` → `state.favoriteCommandIDs`.
  - `func toggleFavorite(qualifiedId:)` saves state.
  - `func noteRun(qualifiedId:)` records recent **only if** `config.palette.firstView == .recent`.
  - Replace every `statusMessage = String(describing: error)` with `UserFacingError.message(for: error)`.

- [x] **Step 1:** No new XCTest in App target. Core pieces already tested. After wiring, `swift test --filter JugnuCoreTests` stays green.
- [x] **Step 2–4:** Implement. Palette still compiles.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 10: Palette product pass

**Files:**
- Modify: `shell/App/PalettePanelController.swift`

**Behavior:**
- Placement: screen whose `frame.contains(NSEvent.mouseLocation)`, else `NSScreen.main`. Center horizontally; `midY + 40` as today.
- On `show()`: reset `query` and `selection` to 0 (host a `PaletteSession: ObservableObject` or recreate `PaletteView` each show so `@State` dies).
- Entrance: `panel.alphaValue = 0`; `orderFront`; animate `alphaValue = 1` over 0.12s. If `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, skip bloom and set alpha 1 immediately (or 0.05s fade).
- Glow-bloom: overlay a brief ember (`theme.accent`) shadow opacity 0→0.35→0 on the rounded rect; omit when Reduce Motion.
- Visual: background `theme.background` / surface, text from theme, `JugnuTokens.Radius.panel`, no `.ultraThinMaterial` as the only fill (material may sit *under* the themed surface at low opacity, but colors must come from theme).
- Search field placeholder: if `index.all.isEmpty` → `No addons yet — install some to get started.`; else rotating `Try ‘…’…` on a 3s timer from `model.index`-equivalent `all` hints; timer pauses while query non-empty.
- Empty query + `firstView == .recent` / `.favorites`: list those commands (not full `all`).
- Debounce: `onChange(of: query)` starts a 100ms Task; cancel previous; then `model.search`.
- Suggestion row (`isSuggestion`): show title + subtitle `Did you mean this?`
- Keyboard: Escape closes; arrows clamp to `results.indices`; Enter runs selection; click = Enter. Pin control on row (star) calls `toggleFavorite` and does **not** run.
- Phosphor: when `config.theme` equals `ThemeConfig.terminalPhosphor` (compare sanitized hex), use monospaced fonts.

- [x] **Step 1:** Manual — no XCTest for AppKit placement. Optionally extract `func screenForMouse(screens: [NSRect], mouse: CGPoint) -> Int` into Core and test it.

```swift
public enum PalettePlacement {
    public static func screenIndex(frames: [CGRect], mouse: CGPoint) -> Int? {
        frames.firstIndex { $0.contains(mouse) }
    }
}
```

Test: two frames, mouse in the second → index 1.

- [x] **Step 2–4:** Implement placement helper + PaletteView.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 11: Shared panel chrome + error banner + toast/confirm/skeleton SwiftUI

**Files:**
- Create: `shell/Sources/JugnuUI/PanelErrorBanner.swift`
- Modify: `ToastPresenter.swift`, `ConfirmPanel.swift`, `SkeletonPanel.swift`
- Modify: `UIHostController.swift` (wire error presenter; keep public panel inits)

**Interfaces:**
- `public struct PanelErrorBanner: View` — `message: String`; uses `theme.error`; one line + wrap.
- Borderless floating `KeyablePanel` for toast/confirm/skeleton (and later list/form). In-content title `Text(ui.title ?? "")` + `JugnuTokens`.
- Confirm: body, Cancel / Confirm (Return = confirm, Escape = cancel). Tab order: Cancel then Confirm.
- Toast: fade in/out; Reduce Motion → no fade, shorter on-screen time (keep today’s reduce-motion shorten).
- Skeleton: text `Loading \(pattern.rawValue)…` — **no** shaped placeholders.
- Follow-up **failure**: set `errorMessage` on the still-open panel; **do not** `dismissActive` + toast.

`ConfirmPanel` gains `func presentError(_ message: String)` (or a bound `ObservableObject`).

- [x] **Step 1:** No Core test. Verify `swift test` still green after rewrite (UIHost still compiles).
- [x] **Step 2–4:** Rewrite three presenters; update `UIHostController.showConfirm` catch path to `panel.presentError(UserFacingError.message(for: error))`.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 12: List + form SwiftUI rewrite

**Files:**
- Modify: `shell/Sources/JugnuUI/ListPanel.swift`
- Modify: `shell/Sources/JugnuUI/FormPanel.swift`
- Modify: `shell/Sources/JugnuUI/UIHostController.swift`

**List behavior (must not regress):**
- Filter as you type (case-insensitive substring on title/subtitle is OK for in-panel filter; this is not CommandIndex fuzzy).
- Arrow keys move selection; Return selects highlighted row; click / double-click select; Escape cancels.
- In-content title; search field placeholder from `ui.placeholder`.
- `presentError` keeps filter text and scroll/selection.

**Form:**
- Fields `text` / `number` / `toggle` as today; Tab through fields; Return submits; Escape cancels.
- `presentError` keeps entered values.

**clipboard-history:** already `ui.pattern: list`. After this task, run it from the palette once (manual) and confirm the list still filters and selecting an item copies back.

- [x] **Step 1–4:** Rewrite; `swift test` green.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 13: NotePanel SwiftUI + floating-note

**Files:**
- Modify: `shell/Sources/JugnuUI/NotePanel.swift`

**Behavior:**
- Keep `.titled, .closable, .resizable` chrome (spec exception).
- `TextEditor`, rich text off, undo via TextEditor.
- Cmd+S and window close both trigger `onSave` with current text (close also `onClose`).
- No `as! NSTextView`. Confirm `.swiftlint.yml` `force_cast` is gone from this file.

- [x] **Step 1–4:** Rewrite; lint the file; manual: palette → Floating Note → type → Cmd+S → close → reopen and confirm persistence still works via the addon.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 14: Sounds + first-run copy + Prefs theme section

**Files:**
- Modify: `shell/App/PrefsView.swift`
- Modify: `shell/App/FirstRunWindow.swift` (user-visible strings)
- Modify: `shell/Sources/JugnuUI/CommandInvoke.swift` and/or `UIHostController` / `AppModel.run`

**Prefs layout (not ticket 0002):**
- Two sections: **Addons** (existing list/toggles/uninstall/install recommended) and **Theme**.
- Theme: three preset buttons Firefly / Terminal Phosphor / Rose Quartz — each `config.theme = preset; try store.save; model.config = config` (triggers `@Published`).
- Color editors: ColorPicker per token for Light and Dark (6 × 2). Writing a picker writes hex back through `JugnuTheme` and save.
- Sound toggle bound to `config.sound`.
- Optional: first-view picker (`Blank` / `Recent` / `Favorites`) — spec requires the config key and palette modules; putting the picker in Prefs is in scope because it is the only settings surface (not catalog browse).

**Sounds:** after toast/error present, if `model.config.sound`, play Tink / Basso. Respect Reduce Motion? Spec does not mute sounds on Reduce Motion — only animation. Leave sounds tied only to `sound:`.

**Live theme:** `PaletteView` and panel SwiftUI roots take `@ObservedObject var model: AppModel` **or** `.environment(\.jugnuTheme, colorsFrom(model.config))` that updates when `model.config` publishes. Do not snapshot theme only in `init`.

**First-run strings:** replace anything technical with restrained copy. Example continue button: `Continue`. Recommended checkbox: `Install a starter set of addons`.

- [x] **Step 1–4:** Implement; `swift test` green.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 15: App icon + menu bar template

**Files:**
- Create: `shell/App/Assets.xcassets/AppIcon.appiconset/` (Contents.json + PNGs)
- Create: `shell/App/Assets.xcassets/MenuBarIcon.imageset/` (template PNG 16pt @2x = 32px)
- Modify: `shell/project.yml` (resources: Assets.xcassets)
- Modify: `shell/App/Info.plist` (`CFBundleIconName` = `AppIcon` if GENERATE_INFOPLIST_FILE is NO)
- Modify: `shell/App/MenuBarController.swift` — `button.image` from named `MenuBarIcon`, `isTemplate = true`; drop the `Jugnu` title (or keep as accessibility fallback if image missing)
- Canonical sources already in repo: `docs/assets/jugnu-icon.svg`, `jugnu-icon-template.svg`, `jugnu-icon-size-ladder.md`

**Render rule:** 1024/512/256/128 may rasterize the master SVG. **64 and below must use the size-ladder glow/stroke values**, not a naive downsample.

Implementation: write per-size SVGs (or a small generator in `scripts/render-appicon.py` using only stdlib string replace) then `qlmanage -t -s N -o dist/` on macOS, or `rsvg-convert` if present. Check the PNGs into `AppIcon.appiconset`.

Apple sizes (macOS): 16, 32, 128, 256, 512, 1024 at 1x and 2x as required by Contents.json.

**Out of scope:** animating the trail for `progress` (no P2 pattern yet). Do not add a spinner.

- [x] **Step 1–4:** Generate, wire, `xcodegen generate`, build Jugnu scheme.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 16: Live-verification target + CI exclusion

**Files:**
- Modify: `shell/Package.swift` — add `JugnuCoreLiveTests`
- Create: `shell/Tests/JugnuCoreLiveTests/RegistryLiveTests.swift`
- Modify: `.github/workflows/ci.yml` — `swift test --filter JugnuCoreTests` (must **not** match `JugnuCoreLiveTests`)
- Modify: `Makefile` — `verify-live` target
- Modify: `shell/README.md` — document the command

**Live tests (macOS, network, real side effects):**
1. Fetch `registry_url` default; find `clipboard-history` and `mic-mute` entries; `AddonInstaller.install` into `JugnuPaths(home: tempHome)`; assert sha256 path succeeded (no throw) and `addon.yaml` exists under temp addons dir.
2. Cleanup test: install `clipboard-history` into **temp** addons dir, then call `AddonLifecycle.uninstall`. Because the addon’s `bin/run` writes a **real** LaunchAgent under `$HOME` when executed, this test should:
   - Snapshot `launchctl list` for `com.jugnu.clipboard-history.watch` **before**
   - Run the installed `bin/run` once with a toast-safe command if needed to force `ensure_watcher` **or** skip the run and instead `Cleanup.performUninstall` on a copied manifest (still deletes declared `~/Library/LaunchAgents/...` if present)
   - `defer` uninstall + `Cleanup.performDisable` even on failure
   - If the agent was **not** present before the test, assert it is absent after; if it **was** present (developer’s own install), do not destroy it — skip the launchd assertion and only assert temp addon dir is gone

Use `XCTSkip` when network fails.

- [x] **Step 1: Failing** — target missing; then tests skip/fail until installer wiring.
- [x] **Step 2:** Confirm `swift test` (no filter) would build the new target — **CI must use `--filter JugnuCoreTests`** so live tests never run on GitHub.
- [x] **Step 3:** Implement tests + CI line + `make verify-live` → `cd shell && swift test --filter JugnuCoreLiveTests`
- [x] **Step 4:** Run default `swift test --filter JugnuCoreTests` green; do **not** run live tests in CI.
- [x] **Step 5: Commit** — skip unless asked.

---

### Task 17: Docs, example config, smoke checklist, shaped-skeleton idea

**Files:**
- Modify: `config/jugnu.example.yaml` — document `theme:`, `sound:`, `palette.first_view:`
- Modify: `docs/architecture/shell-smoke.md` — add palette typing, fuzzy, theme live-reload, keyboard-only, Reduce Motion, permission-denial, hotkey-conflict, floating-note, clipboard-history list, and DEBUG `InvokeTrace` budgets from addon-ui-speed-design.md §6 (hotkey→paint ≤50ms, command→toast ≤150ms; fix only if a real miss)
- Modify: `docs/architecture/README.md` — link this plan as in progress
- Modify: `docs/ideas.md` — add “shaped skeleton placeholders” fast-follow (depends on this epic’s final List/Form/Confirm layouts)
- Modify: `CHANGELOG.md` — one dated Unreleased line for the product pass when behavior lands
- Modify: `docs/backlog.md` platform row 7 if it should cite this plan

Example YAML:

```yaml
sound: true
palette:
  first_view: blank   # blank | recent | favorites
theme:
  light:
    accent: "#C97A12"
    background: "#F7F3EA"
    surface: "#FFFDF8"
    text_primary: "#2A2417"
    text_secondary: "#756E5C"
    error: "#E5484D"
  dark:
    accent: "#F5A623"
    background: "#16130E"
    surface: "#1F1B13"
    text_primary: "#EDE6D9"
    text_secondary: "#8C8577"
    error: "#E5484D"
```

- [x] **Step 1–4:** Write the docs. No code behavior change.
- [x] **Step 5: Commit** — skip unless asked.

---

## Success mapping (spec §7 → tasks)

| Criterion | Task |
|---|---|
| Typing / Esc / Enter / arrows | 10 (manual; typing bug already fixed) |
| Fuzzy ranking | 3 |
| Cursor screen | 10 |
| Shared tokens | 8, 10–13 |
| `swift test` green; hotkey tests in default run; live absent from CI | 5, 16 |
| Recommended set current | 6 |
| Smoke checklist walked | 17 + human |
| Light/dark + invalid hex | 1, 8, 14 |
| Live theme push | 9, 14 |
| Keyboard-only all panels | 10–13 |
| Reduce Motion | 10, 11 |
| Three presets + hand-tune | 8, 14 |

## Explicitly not in this plan

Tickets 0001–0003; VoiceOver; shaped skeletons (ideas.md only); progress-pattern menu-bar trail animation; catalog browse; new addon conversions; Raycast secondary actions (`docs/ideas.md`).
