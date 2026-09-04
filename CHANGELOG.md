# Changelog

All notable changes to Jugnu are documented here.

The project has not published a release yet. Entries currently describe unreleased work.

## [Unreleased]

### Fixed

- 2026-08-29 — Shell panel survives dismiss: `hide()` orders the `KeyablePanel` out instead of destroying it, so a reopen reuses the existing view and skips the cold-paint cost (ticket 0016).

### Added

- 2026-09-05 — First-party `clip-tools` addon: clipboard text format/convert/line commands on the `python-runtime` helper (Phase 1; no Transform panel yet).
- 2026-09-04 — Shared `python-runtime` helper: pinned standalone CPython 3.12.14 for first-party addons (`helpers/python-runtime`, registry row; Release upload still pending).
- 2026-09-04 — Pomodoro, Keep Awake, and Clipboard History no longer hand-roll background work: pomodoro chimes via the clock helper; keep-awake and clipboard-history use shell-owned daemons (ticket 0057 phase 5).
- 2026-09-04 — Crash-loop safe mode, orphan process reaper, and malformed `jugnu.yaml` recovery menu (ticket 0057 phase 4).
- 2026-09-03 — Addon process classes `oneshot` / `job` / `daemon`: job heartbeat watchdog, re-invoke reuse/replace, shell-authored first-party launchd agents, disable-while-running alert (ticket 0057 phase 3).
- 2026-08-29 — Browse Addons and Preferences are searchable launcher rows: type to filter them, arrow-key and Return like any command; `jugnu.yaml` `shell.hidden_shell_commands` hides either one (ticket 0012).
- 2026-08-26 — Shared `clock` helper: versioned timer scheduling installed once and reused by addons.
- 2026-08-26 — First-party `nudges` addon: recurring wellness reminders, three presets, custom nudges, pause/resume, and restore.
- 2026-08-26 — Shell `card` UI pattern for detached, dismissible reminder surfaces with prominent emoji.
- 2026-08-24 — First-party `open-terminal-here` addon: open the last-picked terminal at the front Finder folder (default Terminal; no picker yet).
- 2026-08-24 — First-party `mute-all` addon: mute mic and speakers together, restore saved volumes on the next run.
- 2026-08-24 — Shell view types: ten viewport ids, screen `visibleFrame` clamps, click-outside ignored for `board`/`spread`/`canvas`, manifest `view_types` / command `view` / `ui.view`.
- 2026-08-24 — First-party `window-layouts` addon: AX snaps, snap board, zones (max 6), Space jump via system shortcuts. No undo.
- 2026-08-22 — Added accepted backlog entries for `quick-capture` and `screenshot-inbox`.
- 2026-08-22 — Added accepted backlog entries for `clipboard-guard` and `archive-utility`.
- 2026-08-22 — Added `recent-files` to the accepted addon backlog.
- 2026-08-22 — Added project AI guidance for Jugnu architecture, Swift, macOS, addons, testing, and latency.
- 2026-08-22 — Added a backlog prioritization and implementation workflow prompt under `.prompts/`.

### Documentation

- 2026-09-04 — Drafted `python-runtime` helper and `clip-tools` Phase 1 designs + separate implementation plans (helper first).
- 2026-09-04 — Added living command and UI catalogs (`docs/catalog-commands.md`, `docs/catalog-ui.md`) for shipped + planned addons.
- 2026-08-25 — Approved clock helper + nudges design; plan under docs/superpowers/plans/.
- 2026-08-25 — Removed `apps/` and `extensions/` staging nurseries; unbuilt jobs live only in `docs/backlog.md`. Dropped `docs/staging.md`.
- 2026-08-24 — Locked view types and `window-layouts` product (zones max 6, no undo, AX-first). View types implemented in the shell; `window-layouts` addon follows.
- 2026-08-23 — Added reuse-before-invent / reach-for-this-type rules; SwiftLint errors on force unwrap/cast/try and runs via `make lint-swift` and pre-commit.
- 2026-08-23 — Folded agent-ops copies into `AGENTS.md`; coding standards stay in `docs/conventions.md`.
- 2026-08-23 — Added standing coding conventions (`docs/conventions.md`) and pointed CONTRIBUTING / agent instructions at them.
- 2026-08-23 — Drafted the one-panel / preset / stack shell-surface epic (ticket 0008) and filed 0009–0012 from Browse Addons smoke; parked Liquid Glass in ideas.
- 2026-08-23 — Filed tickets 0005–0007 for Browse Addons palette empty/keyboard, catalog state/errors, and catalog visual follow-up.
- 2026-08-22 — Documented latency as a product requirement with budgets, non-blocking work, instrumentation, and responsiveness testing.
- 2026-08-22 — Added contributor, addon release, changelog, SwiftFormat, and SwiftLint conventions.
- 2026-08-22 — Added addon manifest validation, architecture decisions, contribution templates, security guidance, and a data privacy policy.

### App and Tools

- 2026-08-23 — Palette + addon UI product pass: fuzzy search, shared theme tokens, SwiftUI-hosted panels, live theming, starter-set first-run, app icon.
- 2026-08-22 — Jugnu is a planned native macOS command platform with a hotkey palette and menu-bar shell.
- 2026-08-22 — `clipboard-history` provides local SQLite-backed clipboard search and pins.
- 2026-08-22 — `battery-eta` reports macOS battery percentage, charging state, and ETA.
- 2026-08-22 — `brew-outdated` reports outdated Homebrew packages and related maintenance status.
- 2026-08-22 — `floating-note` provides a lightweight local floating note.
- 2026-08-22 — `pomodoro` provides a local focus timer.
- 2026-08-22 — `weather-bar` provides a local weather status surface.
- 2026-08-22 — `world-clock` displays current times for configured IANA time zones.
- 2026-08-22 — `airdrop-folder` supports a Finder-oriented AirDrop folder workflow.
- 2026-08-22 — `focus-toggle` controls Focus modes through named macOS Shortcuts.
- 2026-08-22 — `mic-mute` controls macOS microphone mute state.
- 2026-08-22 — `open-terminal-here` opens the current Finder context in a terminal.
- 2026-08-22 — `quarantine-clear` supports clearing macOS quarantine attributes from selected files.
