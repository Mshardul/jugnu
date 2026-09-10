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

- [ ] First-run: two steps (keep-current toggles, then checkbox catalog). Skip/close rules and Browse after close are in **Manual — keep current (0063)** below.
- [ ] Preferences → **Install starter addons** downloads zips + verifies sha256
- [ ] Preferences: disable removes from palette; uninstall removes files + declared cleanup
- [ ] **clipboard-history watcher starts on enable** (ticket 0057): enable it without invoking a command; `launchctl print gui/$(id -u)/com.jugnu.clipboard-history.watch` succeeds and `~/Library/LaunchAgents/com.jugnu.clipboard-history.watch.plist` exists. Disable in Preferences → both are gone → log out and back in → watcher does **not** return, no new pasteboard entries recorded
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

## Manual — Addon process lifecycle (0057)

These cannot be fully CI-tested. Walk them on a Mac after phase 4.

- [ ] **Reaper after a shell crash:** invoke a `disowns-child` fixture addon; `kill -9` the `Jugnu` process; relaunch; confirm `~/.local/share/jugnu/state/run/<pid>.json` is gone **and** the orphaned `sleep` child (`pgrep -f sleep`) is gone; confirm one `reap` line in `~/.local/share/jugnu/state/lifecycle.log`.
- [ ] **Real sleep/wake:** start a `job` fixture; `pmset sleepnow`; wake; confirm the mid-flight `job` was torn down and did not resume as a zombie.
- [ ] **`job` stops heartbeating:** run the `stops-heartbeating` fixture as a `job`; confirm SIGKILL + error toast within ~10s (`jobHeartbeatWindow`).
- [ ] **`make stop`:** with a `job` and a `daemon` both running, `make stop`; confirm no tracked child survives **but** the `com.jugnu.*` daemon agent is **still running** (`launchctl list | grep com.jugnu`).
- [ ] **Safe-mode entry:** force 3 hung/crashed launches (e.g. temporarily break `jugnu.yaml`); confirm safe mode boots out `com.jugnu.*` agents on entry (`launchctl list` before/after), the recovery menu shows Reset config / Open config / Disable all addons / Try normal launch again, and one `safe_mode` line is in `lifecycle.log`; fix config → **Try normal launch again** → daemons re-bootstrapped.
- [ ] **PID reuse (best effort):** note a spawned child's `shell_pid`; after a crash + relaunch where the OS happens to reuse that pid, confirm the reaper still reaps by the start-ts mismatch.

## Manual — Addon install & upgrade integrity (0058)

Walk on a Mac after the namespaced `jugnu.*` zips are on `addons-v1.0.0` and `registry/addons.json` is on `main`. Catalog cards use `jugnu.<job>` ids; zip roots match.

- [ ] **Fresh namespaced install:** Browse Catalog → install `jugnu.mic-mute` (or any first-party zip). Confirm `~/.local/share/jugnu/addons/jugnu.mic-mute/addon.yaml` has `id: jugnu.mic-mute` (no bare `id: mic-mute` rewrite needed). Enable → palette row runs.
- [ ] **Cancel mid-install:** start an install, cancel before it finishes. Live `addons/` has no half-tree; `.staging` / `.trash` are empty afterward.
- [ ] **Replace while running:** with an addon process in flight (e.g. `jugnu.keep-awake` duration), trigger Update / reinstall. Confirm the prompt; accept → old process dies before the new tree is live; reject → install aborted, running process stays.
- [ ] **Dependency disclosure:** install an addon that declares a helper (`jugnu.clip-tools` → `python-runtime`) or a catalog dep. The sheet lists what is already installed vs what will be installed, and notes installed ≠ enabled. Helper lands under `helpers/<id>/<version>/`.
- [ ] **Update badge:** with an installed addon older than the registry SemVer, the catalog card shows Update; running it preserves enabled and replaces the tree. Same-version republish does **not** badge.
- [ ] **Namespace migrate (existing install):** a pre-0058 `addons/mic-mute/` tree becomes `addons/jugnu.mic-mute/` on next launch; recents/favorites remap; a second launch is a no-op (completion marker present).

## Manual — keep current (0063)

- [ ] First launch: step 1 defaults on; Skip still leaves both on; step 2 recommended pre-checked; Skip installs nothing and Browse opens
- [ ] Continue step 2 installs checked addons (including a non-recommended if checked)
- [ ] Preferences → Updates toggles persist in jugnu.yaml
- [ ] Menu Check for Updates… with matching 0.1.0 registry: “You’re up to date.”
- [ ] Later on an app prompt does not download; next launch prompts again
- [ ] Keep-addons on + outdated catalog row: bulk confirm; Cancel downloads nothing; catalog per-card Update still works with keep-addons off

## Manual — permissions disclosure (0038)

- [ ] Install `jugnu.window-layouts` from Browse: confirm lists Accessibility; Cancel leaves no tree; Install then enable → first use still OS TCC (Phase A not required yet).
- [ ] Install `jugnu.floating-note`: no permissions confirm.
- [ ] First-launch Continue with recommended including clipboard + network addons: one confirm; expand shows which addons per capability.
- [ ] Card for `jugnu.clip-tools` shows `Needs Clipboard`.
- [ ] Detail for `jugnu.clipboard-history` lists Clipboard and Background agent with reasons.
- [ ] Upgrade fixture: installed without `accessibility`, registry newer with it → Update confirm “newly needs”.

