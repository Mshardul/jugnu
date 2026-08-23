# Changelog

All notable changes to Jugnu are documented here.

The project has not published a release yet. Entries currently describe unreleased work.

## [Unreleased]

### Added

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
