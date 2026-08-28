# Shell MVP — smoke checklist

## Automated (verified 2026-08-22; Core suite re-verified 2026-08-23)

- [x] `cd shell && swift test` — green, 82 tests, 0 failures. Re-verified 2026-08-23 after shell-surface-presets Tasks 1-15 + a follow-up fix: `xcode-select` was pointed at Command Line Tools only (no XCTest module) even with `Xcode.app` present — fixed via `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (system-wide, run by the user). No `DEVELOPER_DIR` override needed anymore.
- [x] `xcodebuild -scheme Jugnu test` — also green, same 82 tests (58 `JugnuCoreTests` + 24 `JugnuUITests`), run via Xcode's native test runner. Fixed 2026-08-23: `project.yml` previously defined no test target/scheme wiring at all. Correct fix (not a hand-rolled `bundle.unit-test` Xcode target — that duplicates the SPM dependency/resource graph and breaks `Bundle.module`, which the tests rely on): XcodeGen 2.46's native `schemes.<scheme>.test.targets: - package: JugnuLocal/<TestTarget>` syntax, which points the Xcode scheme straight at the SPM package's own test targets. Zero duplicate target definitions to maintain.
- [x] Live registry tests live in `shell/TestsExtended/` and are not part of `swift test` / CI
- [x] `xcodegen generate` → `Jugnu.xcodeproj`; `xcodebuild -scheme Jugnu` — **BUILD SUCCEEDED** (re-verified 2026-08-23 after shell-surface-presets Tasks 1-15; regenerated `project.pbxproj` via `xcodegen generate` first since it still listed the deleted `PalettePanelController.swift` from Task 5 — stale entry is gone post-regen, zero `grep` hits for `PalettePanelController`/`BrowseCatalogWindowController`/`UIHostController`/`SkeletonPanel`/`ConfirmPanel`/`ListPanel`/`FormPanel` class names anywhere in `shell/`)
- [x] Launch `Jugnu.app` — process starts (menu bar agent)
- [x] Addon CLI — mic-mute, focus-toggle, paste-plain return `ok: true`
- [x] Release `addons-v1.0.0` + `registry/addons.json` on `main`

Live registry/install (not CI; uses the network and can touch launchd):

```bash
make test-extended
# or: cd shell/TestsExtended && swift test
```

## Manual (on your Mac)

Walk this after the 2026-08-23 palette + addon UI product pass. Leave items unchecked until you actually do them.

### Palette

- [ ] Option+Space (or menu **Open Palette**) opens the palette
- [ ] Typing reaches the search field (not the frontmost app)
- [ ] Escape closes; arrows move the highlight; Enter runs the highlighted row
- [ ] Fuzzy query `mcmt` ranks **Mic Mute** above unrelated keyword matches
- [ ] Empty catalog copy reads `No addons yet — install some to get started.`
- [ ] Did-you-mean row (nonsense query with installed addons) shows subtitle `Did you mean this?`
- [ ] Star pins/unpins without running the command
- [ ] On a multi-monitor Mac, the palette opens on the screen that contains the cursor
- [ ] **Browse Addons** and **Preferences** appear as rows below the addon results (empty query and while typing a matching term like `pref` / `browse`); arrow down onto them, Return opens the catalog / settings (ticket 0012)
- [ ] `shell.hidden_shell_commands: ["preferences"]` in `~/.config/jugnu/jugnu.yaml` removes the Preferences row but the menu-bar **Preferences** item still works

### Theme, motion, sound

- [ ] Preferences → Theme: Firefly / Terminal Phosphor / Rose Quartz each restyle an already-open palette without restart
- [ ] A ColorPicker change on one token (light or dark) pushes live to the open palette
- [ ] Invalid hex in `~/.config/jugnu/jugnu.yaml` falls back per-field instead of crashing
- [ ] Terminal Phosphor uses monospaced UI type; the other two stay SF Pro
- [ ] Reduce Motion on: no glow-bloom; palette fade is instant (or near-instant); toasts do not fade
- [ ] Command success plays Tink, failure plays Basso; Preferences sound toggle silences both

### Keyboard-only panels

- [ ] Confirm (ui-demo): Tab Cancel → Confirm; Return confirms; Escape cancels
- [ ] List (`clipboard-history`): filter as you type; arrows; Return selects; Escape cancels
- [ ] Form (ui-demo): Tab through fields; Return submits; Escape cancels
- [ ] Follow-up failure shows an inline banner and keeps the panel open (no toast-and-dismiss)

### First-run, addons, chrome

- [ ] First-run installs the starter set from registry (falls back to local `addons/` if offline): `mic-mute`, `focus-toggle`, `paste-plain`, `floating-note`, `ports`
- [ ] Preferences → **Install starter addons** downloads zips + verifies sha256
- [ ] Preferences: disable removes from palette; uninstall removes files + declared cleanup
- [ ] **clipboard-history disable stops the watcher for good** (ticket 0023): enable it, invoke `Clipboard history` once, confirm `launchctl print gui/$(id -u)/com.jugnu.clipboard-history.watch` succeeds and `~/Library/LaunchAgents/com.jugnu.clipboard-history.watch.plist` exists → disable in Preferences → both are gone → log out and back in → watcher does **not** return, no new pasteboard entries recorded
- [ ] **Floating Note**: type, Cmd+S, close, reopen — text persisted by the addon
- [ ] Menu bar uses the template firefly icon (tints with the menu bar); click opens the menu
- [ ] **Single-instance guard** (ticket 0020): with Jugnu already running, launch `Jugnu.app` again → the second copy exits immediately, the running copy opens the palette, and Activity Monitor shows exactly one `Jugnu` process. The hotkey still works afterward.

### Nudges and clock helper

- [ ] Enable **Nudges** → three presets visible
- [ ] Set one interval to 30s (test) → card appears with huge emoji
- [ ] Dismiss card → no duplicate stack
- [ ] Pause nudges → no fire; Resume → fires again
- [ ] Delete a preset → Restore presets brings it back
- [ ] Add custom nudge from template → appears and schedules
- [ ] Quit Jugnu → no fire; relaunch → schedules resume without burst of missed cards

### Permissions / hotkey (manual only — do not automate against TCC)

- [ ] Deny a permission an addon needs: the shell shows a human sentence, not `ManifestLoaderError…`
- [ ] Hotkey conflict (e.g. Option+Space already bound): registration fails visibly; changing `shell.hotkey` in config or first-run ⌘Space opt-in recovers

### Felt speed (DEBUG `InvokeTrace`)

Budgets from [addon-ui-speed-design.md §6](./2026-08-22-addon-ui-speed-design.md). Fix only if a real miss shows up — no new logging infra in this epic.

| Path | Target | Hard ceiling |
|---|---|---|
| Hotkey → palette first paint | ≤ 50 ms | 100 ms |
| Command → toast visible | ≤ 150 ms | 400 ms |
| Command → panel chrome (skeleton OK) | ≤ 100 ms | 200 ms |
| Panel chrome → useful content | ≤ 300 ms | 800 ms |
| Follow-up action → feedback | ≤ 150 ms | 400 ms |

- [ ] DEBUG console `InvokeTrace` lines stay inside those budgets on toast addons (mic-mute) and a list panel (clipboard-history)

Default catalog URL: `https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/addons.json` (`shell.registry_url` in config).

## Manual — launcher + catalog foundation (Phase 1)

Walk this after the 2026-08-27 launcher-catalog-foundation plan (viewA row1 favorites bar, fixed 5-slot search-results region, `canvas` remap for catalog/detail/settings). Leave items unchecked until you actually do them.

### Row1 — favorites bar

- [ ] 0 favorites: row1 center is blank, no placeholder text, logo (left) / prefs (right) stay in place
- [ ] Favoriting a command via the search-results star updates row1 within the same session
- [ ] Row1 shows the top 5 favorites in the stored order; a 6th favorited command shows the "…" (`ellipsis.circle`) icon
- [ ] Drag-reorder two favorites in row1; the new order persists after closing/reopening the palette (Opt+Space twice)
- [ ] Right-click a row1 favorite → **Remove from Favorites** removes it without confirmation
- [ ] Click a row1 favorite runs the command exactly as running it from search

### Row2 + search-results region

- [ ] Query with 0 results: did-you-mean suggestion (if any installed command matches) shows in slot 1 with `(did you mean this?)`; "Show all addons →" link still shows
- [ ] Query with exactly 4 results: 4 rows + "Show all addons →" link, no scrollbar
- [ ] Query with >4 results: scrollable region, no "Show all addons →" link
- [ ] Panel height stays visually stable while typing (no per-keystroke resize — confirms the fixed-5-slot rule)
- [ ] Breadcrumb row reads `addon-id › Command Title` (addon id muted, title bold)
- [ ] Search-results star still pins/unpins without running the command

### Canvas remap

- [ ] Catalog / Detail / Preferences panels open at the new (larger, `canvas`-sized) dimensions without visual clipping — full redesign is a later phase, just confirm nothing is broken/cut-off by the `.canvas` remap alone

### Theme token

- [ ] `subText` token resolves per preset×mode (no crash, no black text) — spot-check by eye in each of Firefly / Terminal Phosphor / Rose Quartz
