# Jugnu — palette + addon UI product pass

**Date:** 2026-08-23
**Status:** Approved
**Scope:** Palette interaction/search/visual quality, full AppKit→SwiftUI rewrite of the addon UI host panels (confirm/list/form/toast/skeleton/note) onto shared design tokens, user-editable light/dark theming (config + one Preferences addition), keyboard/motion accessibility, first-run content, shell chrome verification
**Depends on:** [Shell design](./2026-08-22-shell-design.md), [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md)
**Out of scope here:** Persistent latency logging, full addon management / Preferences redesign + catalog browse (theming is the one exception, §4 D), security audit / installer hardening — all three tracked as [tickets](../tickets.md) (§6), not designed in this doc; wiring any *new* real addon to confirm/list/form patterns (deferred — `floating-note`'s existing `note` pattern is the one exception, not new scope, since it's already wired and the rewrite touches it regardless); VoiceOver labels (no current signal it's needed); real shaped skeleton placeholders (fast-follow after this epic, §4 B)

## 0. Why now

Shell MVP + addon UI host P1 are code-complete (all files scaffolded, `swift test` green, registry now live with 11 real addons). The manual smoke checklist in [shell-smoke.md](./shell-smoke.md) was never fully walked — doing so surfaced a real bug (palette accepted the hotkey but not keyboard input, see §1). This epic is the product/UX pass promised by [vision — Surfaces](../vision.md)'s "feel native and intentional... not a sluggish script-runner feel" bar, now that the plumbing underneath it works.

## 1. Bug fixed inline (reference, not a task)

`PalettePanelController` used `NSPanel(styleMask: [.borderless, .nonactivatingPanel])`. `.nonactivatingPanel` tells AppKit the panel must never become key window; a borderless `NSPanel` also defaults `canBecomeKey` to `false`. Net effect: the panel opened and was visible, but the `TextField` never received first-responder status, so typing went nowhere.

Fix applied: dropped `.nonactivatingPanel`, added a `KeyablePanel: NSPanel` subclass overriding `canBecomeKey { true }`, and explicit `panel.makeFirstResponder(hosting)` on show. Build succeeded. **Still needs a manual confirm this reads as fixed in daily use** — fold into §2 verification pass, not a separate task.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Search ranking | Fuzzy subsequence match (Alfred/Raycast-style, e.g. `mcmt` → "Mic Mute"), **tiered by field**: title-tier always outranks keyword-tier always outranks subtitle-tier; fuzzy score only orders results *within* a tier. Ties within a tier break alphabetically by title (matches today's no-query behavior) |
| Palette screen placement | Screen containing the mouse cursor, not `NSScreen.main` |
| Felt speed | Verify by hand against existing `InvokeTrace` budgets; **no new logging infra in this epic** — persistent structured latency logging is [tracked as ticket 0001](../tickets.md). **One real bug found and fixed as part of this, not deferred:** `AddonRunner.run()`'s busy-wait poll loop adds ~0–50ms of dead latency to every invoke (§4 A) |
| Visual design | Full design pass for palette **and** addon UI host panels, built on one shared token set (§3) — not a light touch-up |
| Design tokens | Single source of truth for corner radius, primary/accent color, spacing, type scale — consumed by palette view and all UI-host panels (list/form/confirm/toast) |
| Theming | **Explicit per-mode (light/dark) token values, user-editable two ways: manual YAML/color-picker edits, and a 3-preset picker** (Firefly default, Terminal Phosphor, Rose Quartz — each a full light+dark pair, explored as live mockups and approved). Not system-semantic-only. Theme values live under a **new** `theme:` block in `jugnu.yaml` — not the existing reserved `ui: [String: String]` map on `JugnuConfig`, whose flat shape doesn't fit a nested light/dark struct (same config file as hotkey/addon enablement — [shell-design.md §3](./2026-08-22-shell-design.md)), with a picker/editor UI in `PrefsView` (§ below narrows the Preferences fence for this one addition). **True reactive push, not re-read-on-next-open** — a color change (manual or preset) publishes through `AppModel`'s existing `@Published config`, reflected in any currently-open palette/panel immediately via `@ObservedObject`, no restart and no requirement to close/reopen (§4 D) |
| Accessibility | **In scope:** keyboard-only operability (every panel usable with no mouse — tab order, enter/escape, arrow nav) and Reduce Motion respect (audit against system setting; already promised, unverified, in [addon-ui-speed-design.md §6](./2026-08-22-addon-ui-speed-design.md)). **Out of scope:** VoiceOver labels — no current signal it's needed, revisit later if it becomes one |
| Design tokens — module home | `JugnuUI` SPM target (alongside `JugnuCore`) — **already exists**, no extraction needed (corrected from an earlier wrong assumption, see §3). Holds tokens, theming, **and** the UI-host panel views, which get rewritten from raw AppKit to SwiftUI as part of this epic (`ToastPresenter`, `ConfirmPanel`, `ListPanel`, `FormPanel`, `SkeletonPanel`, `NotePanel`, plus a new shared error banner) — all shared UI, not app-specific. `App/` keeps palette glue, menu bar, hotkey, first-run, prefs |
| Addon UI host scope | Infra + demo-addon polish for `confirm`/`list`/`form`. **No new real addon (clipboard-history, world-clock, brew-outdated, etc.) gets wired to those patterns this epic.** One exception, not new scope: `NotePanel`/`note` pattern already backs the real, shipped `floating-note` addon today — the SwiftUI rewrite (§3, §4 B) affects it regardless, so verifying `floating-note` still works post-rewrite is explicitly included |
| Panel error states | **Inline** — a failed follow-up (e.g. list selection, form submit) shows an error inside the still-open panel via a shared error-banner component; panel never auto-dismisses to a toast on failure, so in-progress input/scroll state isn't lost. One shared component, not duplicated per pattern |
| First-run recommended set | Revisit the hardcoded 3-addon list against the now-11-addon registry |
| Addon management / Preferences | **Narrowed, not fully out of scope.** This epic adds exactly one thing to the existing `PrefsView` stub: the theme picker/editor (see Theming row above). Everything else — addon browse/install, catalog categories, full Preferences redesign — is [tracked as ticket 0002](../tickets.md) |
| Live verification (registry install, cleanup) | Real, automated, but **not part of default CI**. **A physically separate test target** (not a tag on existing tests) — `swift test` and CI never build/run it unless explicitly named, so nothing can silently start running live network tests just because a new test file forgot a tag (§5) |
| Permission-denial / hotkey-conflict behavior | Manual-only checklist item; not worth automating against real macOS TCC state |
| Menu bar / hotkey | Verify + light unit-test hotkey-string parsing/registration logic; **no redesign** this epic |
| Copy/voice tone | **Warm but restrained.** Every shell-owned string (empty states, first-run, button labels, error messages) reads like a human wrote it for another human — plain sentences, no raw system/error dumps leaking through (`ManifestLoaderError.emptyId` must never reach a user) — but never cutesy, no jokes/exclamation-mark energy. Actual personality (distinct "voice," playful copy) is explicitly deferred to a future pass, not this epic — the bar here is "human and precise," not "characterful" |
| Palette entrance | Soft fade-in (~100-150ms) with a subtle warm glow-bloom at the start, echoing the icon's own light motif; Reduce Motion skips the glow-bloom and keeps at most a fast/near-instant fade |
| Sound feedback | Subtle system-sound cue on command success/error (distinct sounds each), via `NSSound`; user-toggleable through a new `sound: true/false` field in `jugnu.yaml` alongside `shell:`/`theme:`, defaulting on |

## 3. Shared design tokens + SwiftUI migration for AppKit panels

**Corrected finding (this epic's planning had it wrong initially):** `JugnuUI` **already exists** as a real SPM target (`shell/Sources/JugnuUI/`, already in `shell/Package.swift`, already depended on by the app) — no module extraction needed. But its panel views are **raw AppKit `NSPanel` subclasses** (`ConfirmPanel`: `NSStackView` + manual constraints; `ListPanel`: `NSTableView` + `NSSearchField`; `ToastPresenter`: manual `NSView`/`CALayer`; `NotePanel`: `NSTextView`), not SwiftUI. Only `PalettePanelController`/`PaletteView` (in `App/`) is SwiftUI-hosted-in-`NSPanel`. `ConfirmPanel`, `ListPanel`, `FormPanel`, `SkeletonPanel`, and `NotePanel` all currently have real title bars (`.titled[, .closable][, .resizable]`) — native chrome, distinct from the palette's and toast's borderless floating-panel look.

**`NotePanel` was missing from earlier drafts of this doc — it's a 5th pattern (`note`) already wired end-to-end** ([addon-ui-speed-design.md §4](./2026-08-22-addon-ui-speed-design.md) names it as "added post-P1"): `UIHostController.showNote`, and it **already backs the real, shipped `floating-note` addon** — not a demo. This means the "no real addon gets converted this epic" boundary (§2) does not fully hold; `floating-note` already depends on this exact code and is affected by the rewrite whether declared in scope or not (§4 B carves out an explicit exception for it).

**Problem:** a SwiftUI environment-based token/theme system (as originally planned) cannot reach raw AppKit views — there is no environment mechanism there. Keeping AppKit and bolting on a parallel `NSColor`-constants theme delivery path would create exactly the "two systems" drift this epic exists to remove.

**Decision: migrate `ConfirmPanel`, `ListPanel`, `ToastPresenter`, `FormPanel`, `SkeletonPanel`, `NotePanel` to SwiftUI hosted in `NSPanel`**, matching `PaletteView`'s existing pattern, as the *vehicle* for this epic's visual + token pass on those views — not a separate migration project bolted on before it. This also resolves the borderless-vs-titled chrome inconsistency, with **one deliberate exception**: `ConfirmPanel`/`ListPanel`/`FormPanel`/`SkeletonPanel` unify to the borderless floating-panel look (matching palette/toast); **`NotePanel` keeps its native title bar and resizability** — a persistent, reopenable scratchpad genuinely benefits from feeling like a real window (draggable by title, resizable), unlike the one-shot ephemeral panels.

**Known porting risk:** `ListPanel`'s `NSTableView`-based filtering (search-as-you-type via `NSSearchFieldDelegate`, double-click-to-select, return-to-select via `keyDown`) needs re-implementing with SwiftUI `List`/`.searchable`/`.onKeyPress` — same shape of thing `PaletteView` already does for itself. `NotePanel`'s `NSTextView` (rich-text-off, undo, Cmd+S-triggers-save, save-on-window-close via `NSWindowDelegate`) is the other real behavior to port carefully — SwiftUI's `TextEditor` is the natural replacement, but the save-on-close and Cmd+S handling need to carry over exactly.

**`JugnuUI` module** (already exists) owns:

- Design tokens (`shell/Sources/JugnuUI/DesignTokens.swift`):

  ```swift
  public enum JugnuTokens {
      public enum Radius { public static let panel: CGFloat = 12 }
      public enum Spacing { public static let panelPadding: CGFloat = 14; /* ... */ }
      public enum Typography { public static let title = Font.headline; /* ... */ }
      // Color is NOT hardcoded here — resolved at runtime from JugnuTheme (below).
  }
  ```

  Radius/spacing/typography stay simple static values (prefer Dynamic Type styles like `.headline`/`.caption` over fixed point sizes — free accessibility scaling). **Color is the one token category that's user-editable** (see Theming below), so it does not live as a static literal in this enum.

- **Theming** (`shell/Sources/JugnuUI/Theme.swift` or similar):

  ```swift
  public struct JugnuTheme: Codable, Sendable {
      public var accent: String       // hex
      public var background: String
      public var surface: String
      public var textPrimary: String
      public var textSecondary: String
      public var error: String
  }
  public struct ThemeConfig: Codable, Sendable {
      public var light: JugnuTheme
      public var dark: JugnuTheme
  }
  ```

  **Default values — the "firefly" direction, explored as a live mockup and approved:** named `ink`/`ember`/`ember-dim`/`parchment`/`dusk`/`signal-red` per the [artifact-design skill](https://claude.ai) exploration. Warm, not the generic cool-blue-on-charcoal-glass every launcher defaults to — literal to the product's own name (Jugnu = firefly; a small warm glow appearing on demand, not Spotlight's cold floodlight).

  | Token | Dark default | Light default |
  |---|---|---|
  | `accent` (ember) | `#F5A623` | `#C97A12` (deeper, holds contrast on a light ground — not a direct reuse of the dark accent) |
  | `background` (ink / paper) | `#16130E` | `#F7F3EA` |
  | `surface` (panel) | `#1F1B13` | `#FFFDF8` |
  | `textPrimary` (parchment / ink-text) | `#EDE6D9` | `#2A2417` |
  | `textSecondary` (dusk) | `#8C8577` | `#756E5C` |
  | `error` (signal-red) | `#E5484D` | `#E5484D` (same both modes — semantic color, kept separate from the accent hue per design-system convention) |

  Both grounds are warm-biased, not neutral grey — a pure grey reads as unconsidered, a grey/paper tone leaning toward the ember hue reads as chosen. These are the **defaults written on first launch**.

  **Two customization paths, both real (not just one):**

  1. **Manual** — hand-edit any individual value under `theme:` in `jugnu.yaml`, or via the color pickers in `PrefsView` (§4 D). Fully free-form; a preset is just a starting point, not a constraint.
  2. **Presets** — `PrefsView`'s theme section also offers **3 curated presets** (each a complete light+dark `ThemeConfig` pair), explored as live mockups and approved. Picking one overwrites all 12 values (6 tokens × 2 modes) at once via `ConfigStore.save`; the user can still hand-tune individual values afterward — presets are a starting point, not a locked mode.

  | Preset | Accent family | Dark `accent` | Dark `background` | Dark `surface` | Dark `textPrimary` | Dark `textSecondary` | Light `accent` | Light `background` | Light `surface` | Light `textPrimary` | Light `textSecondary` |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | **Firefly** (default) | warm amber | `#F5A623` | `#16130E` | `#1F1B13` | `#EDE6D9` | `#8C8577` | `#C97A12` | `#F7F3EA` | `#FFFDF8` | `#2A2417` | `#756E5C` |
  | **Terminal Phosphor** | green / CRT | `#39FF6A` | `#020402` | `#020402` | `#C9FFD4` | `#3A8A4A` | `#1C8A3F` | `#EEF3EC` | `#F7FAF6` | `#12291A` | `#4F6D57` |
  | **Rose Quartz** | pink / magenta | `#F0559B` | `#210F1A` | `#2E1524` | `#FBE6F1` | `#B98AA7` | `#D13D82` | `#FDF0F6` | `#FFFAFD` | `#4A1936` | `#93677F` |

  `error` stays `#E5484D` across all three presets and both modes — kept semantic, deliberately not part of any preset's accent identity (per design-system convention: semantic color is separate from the accent hue). Terminal Phosphor is also the one preset that pairs naturally with a monospace type treatment in the UI (SF Mono throughout, not just for command ids) — a visual detail worth carrying into the actual SwiftUI implementation, not just the mockup.

  Preset source of truth: three static `ThemeConfig` values shipped in code (e.g. `JugnuTheme.presets: [String: ThemeConfig]` in `JugnuUI`), not fetched from anywhere — no network dependency for something this core to first-launch appearance.

  **Config key — checked, not assumed:** `JugnuConfig` (`shell/Sources/JugnuCore/Models.swift`) already has a reserved-but-unused `ui: [String: String]` map. That shape (flat String→String) can't hold a nested light/dark color struct without an awkward JSON-in-a-string encoding, so theme values get their **own new sibling `theme:` key** (a `ThemeConfig` field on `JugnuConfig`), not the existing `ui` map — leave `ui` reserved for whatever it was originally meant for. Parsed by `ConfigStore`/`JugnuConfig` the same way `shell:`/`addons:` are today, with built-in defaults written on first launch (same "missing config → write defaults" behavior `ConfigStore` already has per [shell-design.md §3](./2026-08-22-shell-design.md)). At runtime, `JugnuUI` resolves the active theme from `NSApp.effectiveAppearance` (or SwiftUI's `colorScheme` environment value) and hands `light`/`dark` `JugnuTheme` down as a SwiftUI environment value — palette and every panel read colors from environment, never from a hardcoded token. Invalid hex values fall back to the built-in default for that field (never crash on a bad user-edited YAML value).

  **Preferences addition — real scope, not just "add a section":** the existing `PrefsView` (`shell/App/PrefsView.swift`) is a genuinely bare stub today — a plain `.padding(16)` VStack with an addon list, one enable toggle, one uninstall button, one "install recommended" button, no visual structure at all (no sections, no headers beyond a single `Text("Addons")`). Bolting a fully-designed theme section onto that as-is would look inconsistent (one polished section next to an undesigned rest-of-view). This task therefore includes minimal structural tidy-up of `PrefsView` itself (e.g. a simple sectioned layout: "Addons" / "Theme"), built on the same tokens as everywhere else — not a full Preferences redesign (that's [ticket 0002](../tickets.md)), just enough so the new theme section doesn't look bolted onto nothing.

- The UI-host panel views themselves, rewritten in place as SwiftUI (per the migration decision above): `ToastPresenter`, `ConfirmPanel`, `ListPanel`, `FormPanel`, `SkeletonPanel`, `NotePanel`, plus a new shared `PanelErrorBanner` (§4 B). Already live in `shell/Sources/JugnuUI/` — no file move needed, only a rewrite of their internals.

`shell/App/` keeps everything palette- and app-shell-specific: `JugnuApp.swift`, `MenuBarController`, `HotkeyController`, `PalettePanelController`/`PaletteView`, `FirstRunWindow`, `PrefsView`. This split already matches how the code is organized today; `App` depends on both `JugnuCore` and `JugnuUI`, `JugnuUI` depends only on `JugnuCore`.

Every palette/panel view consumes tokens, never literals. Token/theme definitions land first; the SwiftUI rewrite of each panel (§4 B) consumes them as it goes, alongside the palette's own visual pass (§4 A) — these can proceed in parallel once tokens exist, panel-by-panel is fine, they don't block each other.

**App icon:** designed from scratch this epic (none existed before). **Canonical source files, checked into the repo, not just described in prose:**

- [`docs/assets/jugnu-icon.svg`](../assets/jugnu-icon.svg) — 1024px master (correct as-is at 1024/512/256/128px)
- [`docs/assets/jugnu-icon-template.svg`](../assets/jugnu-icon-template.svg) — monochrome `NSStatusItem` template variant for the menu bar
- [`docs/assets/jugnu-icon-size-ladder.md`](../assets/jugnu-icon-size-ladder.md) — exact tuned glow-radius/stroke-width/dash-pattern values for 64/48/32/16px, verified legible during design; **use these values directly when generating the `.appiconset` PNGs for those sizes — do not naively rasterize the 1024px master down**, the glow and trail disappear at small sizes without the compensating scale-up baked into these per-size values

Concept: a small dark speck (the firefly itself, implied by proportion/darkness rather than drawn anatomy — insect illustration/silhouette approaches were explored and explicitly rejected, see design-exploration notes below) sitting inside a warm radial glow (hot-white core → `#fff2d9` → ember `#f5a623` → transparent), with a dashed, gradient-faded flight trail (bright near the glow, fading to nothing at the tail) suggesting motion. Confirmed the template variant reads correctly on both light and dark menu bars.

**Implementation task (not done this session, deliberately deferred to the implementation plan):** render the size-ladder into a real Xcode `AppIcon.appiconset` (16/32/64/128/256/512/1024 @1x/@2x per Apple's asset catalog convention), wire it into `shell/project.yml`/`Info.plist`, export the template SVG as a 32×32px (@2x for 16pt) PNG for `NSStatusItem.button.image` with `isTemplate = true`, and rebuild to confirm both actually render.

**Menu bar icon — in-progress state (new, this round):** during any long-running addon operation (a `progress`-pattern command, per [addon-ui-speed-design.md §4](./2026-08-22-addon-ui-speed-design.md)'s P2 roadmap — not otherwise in this epic's scope), the menu bar icon's flight trail **animates as if lighting up segment-by-segment toward the glow**, rather than a generic blinking/pulsing opacity loop. Deliberately chosen over blinking: it reuses the icon's own existing visual language (the trail already exists as static art) instead of a generic spinner cliché every app already uses. Respect Reduce Motion: freeze on a static mid-lit trail state instead of animating. **Scope note:** this is a small addition to `MenuBarController` (an animated variant of the template icon), gated on P2's `progress` pattern actually existing — if P2 isn't pulled into this epic, this is prep/design-only (the animation concept is decided, wiring it to a real progress event is not blocked on anything in this epic's other fronts, but has no live trigger until a `progress`-pattern addon exists).

Design exploration (for context, not to be repeated): went through 4 rounds before landing here — (1) literal insect-body silhouettes (beetle shape + wings), rejected as "robotic"/mechanical-looking; (2) bare abstract glow blobs with no insect reference at all, rejected as "too minimalist"/lacking presence; (3) fully illustrated firefly characters (body, translucent wings, antennae, legs), rejected — any drawn insect anatomy read badly regardless of style; (4) the locked direction — a tiny dark speck + glow + trail, firefly implied by proportion and darkness the way real firefly imagery (children's books, night scenes) typically depicts it, never by drawing the creature. Two further passes tuned brightness/centering and the trail's visibility against the glow's size.

## 4. Depth by front

### A. Palette + speed

- Fix and re-verify interaction correctness beyond the typing bug: Escape-always-closes, arrow-key selection stays in sync when the list re-filters mid-navigation, click-to-run behaves same as Enter, panel state resets (query/selection) on each fresh open.
- Replace substring search in `CommandIndex` with fuzzy subsequence matching, tiered by field (title-tier > keyword-tier > subtitle-tier); fuzzy score only orders results within a tier, ties break alphabetically by title.
- **"Did you mean" on zero results:** when fuzzy search returns nothing for a non-empty query, surface the single closest-matching command (best fuzzy score even below whatever cutoff normally excludes it) as a soft suggestion, instead of a flat "no results." Small addition on top of the fuzzy-matching work above — reuses the same scoring, just relaxes the display cutoff for exactly one row when the normal result set is empty.
- Palette placement: open on `NSScreen` containing current mouse location, not `NSScreen.main`.
- **Empty states, two distinct cases:** (1) query is empty but addons exist — the search field placeholder **rotates through real installed commands** ("Try 'mute mic'…", "Try 'battery'…", drawn from `CommandIndex.all`, not hardcoded strings) instead of a static "Search commands"; teaches discoverability using real content, no separate empty-state screen needed. (2) zero enabled addons at all (fresh install, pre-first-run) — rotating hints don't make sense with nothing to try, so this shows quiet fallback copy instead (exact wording per the copy-tone standard below, e.g. "No addons yet — install some to get started").
- **Modular empty-query "first view" — not silent recent-command tracking.** Considered biasing search ranking toward recently/frequently run commands by default; rejected as a privacy overreach to build a usage profile without explicit consent. Instead: the empty-query view is itself a **user-selectable module** — a new `palette.firstView` config value in `jugnu.yaml` (alongside `theme:`/`shell:`), one of `blank` (current behavior, the rotating-placeholder empty state above — **default**), `recent` (last N run commands, only if the user opts in), or `favorites` (user-pinned commands, favoriting mechanism itself is a separate small feature — pin/unpin a command from its row). Each is a distinct, swappable view builder, not a ranking tweak baked silently into `CommandIndex.search`. This is the concrete instance of `ui: {}`'s reserved intent in [shell-design.md §3](./2026-08-22-shell-design.md) ("everything configurable later including first screen").
- **Debounced search-as-you-type — no explicit trigger needed.** Confirmed `PaletteView.onChange(of: query)` already calls `model.search(newValue)` on every keystroke with no debounce (`shell/App/PalettePanelController.swift`) — for a fast in-memory substring/fuzzy match over ~30 commands this is currently harmless, but worth being deliberate rather than accidental: add a short debounce (~80-120ms) on the search call so a fast typist doesn't trigger a full re-filter+re-render on every single keystroke. Keep it short enough to stay invisible against the felt-speed budgets already in scope — this is a performance/smoothness safeguard, not a UX-visible delay.
- **Palette entrance animation:** currently `panel.makeKeyAndOrderFront(nil)` shows the palette instantly, no transition at all. Add a soft, quick fade-in (~100-150ms) with a subtle warm glow-bloom at the very start of the animation — echoes the icon's own light motif, stays within the felt-speed budgets already in this epic (§2 Felt speed row) rather than adding perceptible delay. Respect Reduce Motion: skip the glow-bloom, keep at most a very fast/near-instant fade (or none) when the system setting is on.
- **Sound feedback on command run/error:** a subtle system-sound cue (e.g. `NSSound` playing a short built-in system sound, distinct sounds for success vs error) on command completion, matching the tactile feedback pattern Spotlight/Alfred/Raycast already use. Must respect a mute/disable option (some users find UI sounds intrusive) — add a `sound: true/false` field alongside the existing `theme:`/`shell:` blocks in `jugnu.yaml`, defaulting to on but trivially toggled off.
- Full visual pass on `PaletteView`, built on tokens from §3, reading colors from the active `JugnuTheme` (light/dark) — verify both modes look intentional, not just "system default happened to work."
- Keyboard-only operability: confirm the palette is fully usable with no mouse (tab order into the text field, arrow nav, enter/escape) — this already mostly exists per current `.onKeyPress` handlers, verify it holds after the visual pass, don't regress it.
- Reduce Motion: audit any palette open/close or selection-highlight animation against the system Reduce Motion setting; this was already promised in [addon-ui-speed-design.md §6](./2026-08-22-addon-ui-speed-design.md) ("motion is hierarchy, not decoration spam") and never verified.
- Felt-speed verification: run the real app against real addons (not artificial `sleep` fixtures), read `InvokeTrace.debugDescription` output in DEBUG, confirm budgets from [addon-ui-speed-design.md §6](./2026-08-22-addon-ui-speed-design.md) hold. Fix only if a real miss turns up — do not build new instrumentation here.
- **Found and fixed inline (not a "maybe" — a real bug):** `AddonRunner.run()` (`shell/Sources/JugnuCore/AddonRunner.swift`) waits for the addon process via a busy-wait poll loop (`while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }`), adding up to ~50ms of dead polling latency to **every single invoke** — a real chunk of the felt-speed budgets this epic exists to protect (toast target is ≤150ms). It's called from `Task.detached` (`AppModel.run`), so it doesn't block the main thread, but it's still 0–50ms of pure waste baked into the runner that `InvokeTrace`'s external timestamps wouldn't surface as a distinct cause. Replace the poll loop with `Process.terminationHandler` (async, no sleep) so the runner returns the instant the process actually exits.

### B. Addon UI host surfaces

- Rewrite `ToastPresenter` / `ConfirmPanel` / `ListPanel` / `FormPanel` / `SkeletonPanel` from raw AppKit (`NSStackView`/`NSTableView`/manual `CALayer`) to SwiftUI hosted in `NSPanel`, matching `PaletteView`'s existing pattern (§3) — built on the same tokens + `JugnuTheme` as the palette so palette and panels read as one system in both light and dark, and unify chrome (drop `ConfirmPanel`/`ListPanel`/`FormPanel`/`SkeletonPanel`'s current native title bars in favor of the borderless floating-panel look already used by palette/toast, unless a specific case argues otherwise).
- The addon-supplied title (currently the OS title-bar text) moves in-content — rendered inside the SwiftUI view itself (e.g. a header row) — so no information is lost when the system title bar goes away.
- `SkeletonPanel` keeps its current "Loading {pattern}…" concept for this epic (just rewritten in SwiftUI with tokens/theme) rather than building real shaped/shimmer placeholders now — those depend on List/Form/Confirm's *final* SwiftUI layouts being settled, which happens as part of this same rewrite, so building a shaped skeleton in parallel means guessing at a layout that's still moving. **Fast-follow, not one of the tracked tickets (§6):** once this epic's panel layouts land, a follow-up task should replace the loading text with real shaped skeletons — note this explicitly so it isn't lost the way "verify the smoke checklist" almost was.
- Port `ListPanel`'s existing filter/select/keyboard behavior carefully during the rewrite — search-as-you-type, click/double-click select, return-to-select — this is real interactive logic, not just layout, and the one place regressions are likely.
- Keyboard-only operability across all four panel types: tab order through form fields, arrow nav in lists, enter/escape on confirm — verify each is usable with no mouse (this is a fresh requirement on the rewritten SwiftUI views, not just a check on what already exists).
- Reduce Motion: `ToastPresenter` already checks `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` to shorten its dismiss timing — carry that forward (or improve it) in the rewrite; audit the other panels' transitions (skeleton→content swap, confirm/list/form open animation), which currently have no such check.
- Verify skeleton-first chrome against realistic (not artificial) latency where possible.
- Implement in-panel error states for follow-up failures (e.g. a `list` selection's follow-up call fails) via one shared `PanelErrorBanner` component, used consistently by list/form/confirm — panel stays open, banner shows the error, no auto-dismiss-to-toast.
- Infra + demo addons (`ui-demo-list/form/confirm`) only for `confirm`/`list`/`form` — no new real addon gets converted to those patterns this epic.
- **`NotePanel` + `floating-note` (real addon, not a demo):** rewrite `NotePanel` to SwiftUI (`TextEditor` for the `NSTextView`), keeping its native titled/resizable chrome (§3), carrying over save-on-window-close and Cmd+S-triggers-save exactly. Manually verify `floating-note` still works end-to-end post-rewrite — this is the one place the rewrite touches a real, already-shipped addon, so it needs real verification, not just a demo-addon check.
- **Free lint cleanup, noted so it's not lost:** `NotePanel.swift:21` currently has `scrollView.documentView as! NSTextView`, a force-cast SwiftLint already flags at `warning` level (`.swiftlint.yml`'s `force_cast: warning`). This goes away entirely once `NSTextView`/`NSScrollView` are replaced by SwiftUI's `TextEditor` — not a separate task, just worth confirming it's actually gone (no new force-casts introduced elsewhere in the rewrite) rather than assuming.

### C. First-run (trimmed)

- **Found duplication:** the 3-addon recommended list is hardcoded independently in two places — `ShellConfig.recommendedAddonIDs` (`shell/Sources/JugnuCore/Models.swift`) and `FirstRunWindow.recommendedLocalRoots()` (`shell/App/FirstRunWindow.swift`, its own separate `["mic-mute", "focus-toggle", "paste-plain"]` array used only to locate local dev fallback paths). Consolidate: `recommendedLocalRoots()` should look up local paths for whatever IDs `ShellConfig.recommendedAddonIDs` names, not hardcode its own copy — otherwise this epic's own task (updating the recommended set) immediately reintroduces drift between the two.
- Update `ShellConfig.recommendedAddonIDs` against the current 11-addon registry — decide the new curated set (not necessarily all 11) — as the single source of truth once consolidated.
- Live-verify (see §5) the install-from-registry path against the real `addons-v1.0.0` release: download, sha256 match, unpack.
- **Checked, not hypothetical:** 4 of the 11 real addons declare non-empty `cleanup.paths` — `clipboard-history`, `floating-note`, `pomodoro`, `ports` (all under `~/.local/share/jugnu/state/<id>`). `clipboard-history` is the one addon with a non-empty `cleanup.launchd` too (`com.jugnu.clipboard-history.watch`, a real background launchd watcher agent + its plist under `~/Library/LaunchAgents/`). Live-verify disable/uninstall against **`clipboard-history` specifically** — it's the only real exercise of `Cleanup.bestEffortLaunchctlBootout` (which tries `launchctl bootout` then falls back to `launchctl unload`), not just path deletion. Confirm the watcher agent is actually stopped (e.g. `launchctl list | grep clipboard-history` before/after), not just that the plist file is gone.
- Full addon-management UI, browse/discover, catalog categories: **out of scope**, [tracked as ticket 0002](../tickets.md).

### D. Theming (config + Preferences)

- Add `theme:` block to `JugnuConfig`/`ConfigStore` (`shell/Sources/JugnuCore/`) — `ThemeConfig { light: JugnuTheme, dark: JugnuTheme }` per §3. Defaults written on first launch, same pattern as existing config fields.
- Runtime theme resolution in `JugnuUI`: read `NSApp.effectiveAppearance` / SwiftUI `colorScheme`, hand the matching `JugnuTheme` down as an environment value.
- Invalid/malformed hex values in a hand-edited YAML fall back to the built-in default for that field — never crash.
- `PrefsView` gains a theme section with **two controls**: (1) a preset picker — 3 buttons/swatches for Firefly / Terminal Phosphor / Rose Quartz (values in §3), each overwriting the full `ThemeConfig` in one `ConfigStore.save` call; (2) individual editable color values (accent, background, surface, text, error) for light and dark, for hand-tuning on top of (or instead of) a preset. This is the only Preferences work in this epic (§2 table) — no addon browse/install here.
- Preset values are static Swift data (`JugnuTheme.presets`, §3), not fetched — no network dependency for something this core to first-launch appearance.
- **Live reload — real mechanism, not just a label:** checked `AppDelegate.showPrefs()` (`shell/App/JugnuApp.swift`) — Preferences is created fresh each time it's opened (a new `NSWindow`/`NSHostingController`, not a stored singleton), while `palette`/`menuBar`/`hotkey` *are* stored properties on `AppDelegate`. A "re-read config on next open" approach (mirroring how `AppModel.refreshIndex()` already re-reads config/addons) would be the simple option, but the locked decision is **true reactive push**: `AppModel` (already `ObservableObject`, already holds `@Published var config: JugnuConfig`) publishes the active `JugnuTheme` whenever `ConfigStore.save` is called from the theme editor, and any currently-open palette or panel observes it directly — not just on next open. Concretely: expose the resolved `JugnuTheme` as a `@Published` value on `AppModel` (recomputed on `config` change, itself already `@Published`), and have `PaletteView`/panels read it via `@ObservedObject`/environment rather than a one-time snapshot at open time.
- This front's output (the `JugnuTheme` type + reactive publishing) is a dependency of A and B's visual passes — sequenced before or alongside the `JugnuUI` panel rewrite in §3, not after.

### E. Shell chrome

- Manual verification pass: menu bar items work as documented, Option+Space opens/toggles palette, hotkey survives a config change + relaunch.
- Unit tests for hotkey string → key-combo parsing/registration logic (deterministic, no real OS permission state needed).
- Manual-only: permission-denial behavior (revoke Input Monitoring/Accessibility, relaunch, confirm menu-bar-only fallback; re-grant, confirm recovery) and hotkey-conflict behavior (Option+Space already bound elsewhere) — not automated, checked periodically by hand.
- No menu bar redesign, no hotkey-rebind UI this epic.

## 5. Live-verification test suite (cross-cutting)

Some "verify by hand" items in C and E are actually deterministic and worth automating — they just shouldn't run on every commit (network calls to a real GitHub release, real filesystem side effects from real addon zips).

- **New, physically separate SPM test target** `JugnuCoreLiveTests` (own folder `shell/Tests/JugnuCoreLiveTests/`, own entry in `shell/Package.swift`) — not a tag on tests inside the existing `JugnuCoreTests` target. `swift test` with no arguments builds/runs every target by default, so the separation must be structural: nothing added to this new target can ever run just by someone forgetting a tag on a new test.
- Covers: registry fetch + sha256-verified install against the real `addons-v1.0.0` release; disable/uninstall cleanup against a real (not fixture) addon — specifically `clipboard-history` (§4 C), the one addon with a real `launchd` cleanup entry, not just path deletion.
- **Safety note:** a `clipboard-history` live-cleanup test genuinely loads/unloads a launchd agent (`com.jugnu.clipboard-history.watch`) on the machine running it. This is exactly why the suite must never run in CI (an ephemeral CI runner is one thing; a developer's real Mac gaining/losing a background agent as a side effect of running tests is different) — confirm the test tears down cleanly even on failure (a test that installs the agent then fails before uninstalling would leave it running).
- `.github/workflows/ci.yml` currently runs bare `swift test` (line ~75), which builds/runs every target by default — this **must change** to `swift test --filter JugnuCoreTests` (or equivalent explicit exclusion) as part of this task, or the new live target runs on every CI push, defeating the point.
- Invoked explicitly for local/periodic runs, e.g. `swift test --filter JugnuCoreLiveTests` or a `make verify-live` target — document the exact command in `shell/README.md`.
- Run periodically by hand (every few days / before a release), not gated on every push.
- Permission-flow and pure visual/feel checks stay in the manual checklist ([shell-smoke.md](./shell-smoke.md)) — they are not candidates for this suite.

## 6. Future work (tracked as tickets, not designed here)

Split out during this epic's planning — see [docs/tickets.md](../tickets.md) (rows 0001–0003) for each one's intent and any seeded findings: persistent latency logging, addon management / settings (Preferences redesign), and a security audit (seeded with a real zip-slip finding in `AddonInstaller.unzip()`, found while planning this epic).

Also noted, but lower-confidence than a ticket — see [docs/ideas.md](../ideas.md): secondary actions / hold-modifier preview on palette rows (Raycast-style actions panel), deferred as real new interaction scope, not yet committed to a future epic.

## 7. Success criteria

1. Typing in the palette works reliably; Escape/Enter/arrow-key nav verified by hand, not just by reading code.
2. Fuzzy search returns sensibly ranked results across the current ~30+ commands across 11 addons.
3. Palette opens on the cursor's screen on a multi-monitor setup.
4. Palette and all UI-host panels share one token set; changing a token (e.g. corner radius) visibly changes both without touching each view's literals.
5. `swift test` stays green; new hotkey-parsing unit tests included in the default run; live-verification suite passes when run manually and is confirmed absent from CI.
6. First-run recommended set reflects a deliberate current choice, not a stale 3-of-3-that-existed-then.
7. Manual smoke checklist ([shell-smoke.md](./shell-smoke.md)) fully walked at least once, including the permission-denial and hotkey-conflict items.
8. Palette and every panel render correctly in both light and dark mode using user-editable `theme:` values from `jugnu.yaml`; an invalid hex value falls back to defaults instead of crashing.
9. A user can open Preferences, change a theme color, and see it reflected in a currently-open palette/panel immediately (via `AppModel`'s reactive publishing, not by closing and reopening).
10. Every palette/panel interaction (open, search, select, submit, confirm, cancel) is completable with keyboard only, no mouse.
11. Reduce Motion, when enabled system-wide, visibly changes/removes palette and panel animations.
12. A user can pick any of the 3 presets (Firefly, Terminal Phosphor, Rose Quartz) from Preferences and see the full palette/panel set adopt it correctly in both light and dark mode; picking a preset doesn't prevent hand-tuning individual values afterward.

## Related

- [Vision — Surfaces](../vision.md)
- [Shell design](./2026-08-22-shell-design.md)
- [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md)
- [Backlog](../backlog.md)
- [Shell smoke checklist](./shell-smoke.md)
- [Tickets](../tickets.md) — future epics split out of this doc
- Architecture index: [README](./README.md)
