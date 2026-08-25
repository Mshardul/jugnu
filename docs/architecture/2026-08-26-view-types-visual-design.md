# Jugnu — view types visual design

**Date:** 2026-08-26
**Status:** In progress — findings only, to be reviewed, scope only. Split out while auditing per-addon view-type assignment ([view types §7](./2026-08-24-view-types.md#7-per-addon-view-type-assignment--locked-2026-08-26)) — the ten-type catalog is locked as *geometry* (size band, aspect, chrome), but most types have never had a real visual design pass, only the launcher/catalog surfaces this session covered (`seek`, `palette`, `canvas`).
**Depends on:** [View types](./2026-08-24-view-types.md) (owns the geometry contract this epic designs the visuals for), [Launcher + catalog design](./2026-08-25-launcher-catalog-design.md) (the three already-mocked types), [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) (locks the SwiftUI-migration mechanism for the panel host views, not their look)

## 0. Purpose

The shell's fixed viewport catalog ([view types](./2026-08-24-view-types.md)) has ten in-panel types plus three non-panel mechanisms (`toast`, `note`, `status`). Only three of those thirteen have a real visual mockup so far — `seek` and `palette` (viewA, empty/results states) and `canvas` (viewB, detail view, Preferences) — all from this session's launcher/catalog design work. The other ten have never been visually designed, only named and geometrically specced.

This epic covers a visual design pass — real mockups, in the visual companion, one representative real addon per type where one exists ([view types §7](./2026-08-24-view-types.md#7-per-addon-view-type-assignment--locked-2026-08-26) has the current addon→type assignments) — for every remaining type.

## 1. Types still needing visual design

| Type | Aspect/band (locked geometry) | Real addon example available | Notes |
|---|---|---|---|
| `ask` | wide, tiny, dialog | `ui-demo-confirm` | Confirms |
| `fields` | portrait, short form | `pomodoro`, `keep-awake`, `ui-demo-form` | Options/forms |
| `rows` | portrait, filterable list | `ports`, `clipboard-history`, `battery-eta`, `world-clock`, `brew-outdated`, `ui-demo-list` | Most-occupied type — several real examples to choose from |
| `grid` | landscape, ~40% gallery | none yet | Currently unoccupied by any real addon — likely home for the [tools launcher epic](./2026-08-26-tools-launcher-design.md) |
| `board` | landscape, ~40% spatial | `window-layouts` | Snap board |
| `spread` | landscape, ~40–50% two-pane | none yet | Currently unoccupied |
| `rail` | portrait, medium height, narrow | (Preferences and viewB detail view *reference* `rail` as an earlier candidate, but both ended up `canvas` instead — see [launcher + catalog design §3.3](./2026-08-25-launcher-catalog-design.md)) | No confirmed real occupant yet |
| `toast` | HUD, not a panel type | `mic-mute`, `mute-all`, `focus-toggle`, `open-terminal-here`, `paste-plain` (all TBD, pending this epic) | Current AppKit implementation described as visually poor ("horrible") during this session's audit — a from-scratch pass, not a polish pass. ≤150ms latency budget already locked (product pass). |
| `note` | detached, persistent | `floating-note` | Keeps native title bar/resizability per product pass §3 (deliberate exception to the borderless-panel unification) |
| `status` | menu bar | — | Overlaps with the [menu bar epic](./2026-08-26-menubar-design.md) — coordinate scope rather than design twice |

## 2. Findings carried forward

- **Geometry is locked, visuals are not.** Nothing in this epic should reopen size bands, aspect ratios, or the ten/thirteen-type count — [view types](./2026-08-24-view-types.md) already locked that. This epic is purely "what does each type look like when it has real content in it."
- **In-panel error banner** (`PanelErrorBanner`) is a shared component used across list/form/confirm content — relevant when designing `rows`/`fields`/`ask` visuals, but its own full design is the separate [error & failure states epic](./2026-08-26-error-failure-states-design.md) — coordinate, don't duplicate.
- **SwiftUI migration already decided** for the panel host views (`ConfirmPanel`, `ListPanel`, `FormPanel`, `SkeletonPanel`, `NotePanel`, `ToastPresenter`) — borderless floating-panel look for all except `NotePanel` (keeps native title bar). This epic designs what goes *inside* that shell, building on the same `JugnuTheme` tokens already used by `seek`/`palette`/`canvas`.
- **`rows` is the most contested type** — 6 real addons currently assigned to it, spanning genuinely different content shapes (single-value status glance vs. multi-row lists vs. filterable-with-action lists). Worth checking during design whether `rows` needs internal visual variation (e.g. a one-row vs. multi-row treatment) or whether one consistent look serves all of them.
- **`toast` blocks 5 addons' view-type finalization** — see [view types §7.1] and the addon table above.

## 3. Open questions (not yet explored)

- Design order — start with the most-occupied/highest-value type (`rows`, 6 addons) or the most urgent unblock (`toast`, blocking 5 addons)?
- `grid`: design generically first, or wait until the [tools launcher epic](./2026-08-26-tools-launcher-design.md) needs it (likely first real occupant)?
- `rail`: no confirmed real occupant since both candidate surfaces (Preferences, detail view) ended up as `canvas` instead — does `rail` need a design pass at all yet, or stay speculative until something actually claims it?
- `status` (menu bar): fully owned by the [menu bar epic](./2026-08-26-menubar-design.md), or does this epic own the *type*'s mechanics while that epic owns the icon/dropdown content?

## Related

- [View types](./2026-08-24-view-types.md) — geometry contract, §7 per-addon assignment
- [Launcher + catalog design](./2026-08-25-launcher-catalog-design.md) — the three already-mocked types (`seek`, `palette`, `canvas`)
- [Error & failure states epic](./2026-08-26-error-failure-states-design.md) — shared `PanelErrorBanner`, coordinate not duplicate
- [Tools launcher epic](./2026-08-26-tools-launcher-design.md) — likely first real `grid` occupant
- [Menu bar epic](./2026-08-26-menubar-design.md) — overlaps on `status`
- [Ticket 0052](../tickets.md) — tracking row, points here
- Architecture index: [README](./README.md)
