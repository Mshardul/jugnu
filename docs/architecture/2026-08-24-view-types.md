# Jugnu — view types (viewport catalog)

**Date:** 2026-08-24  
**Status:** Approved — implemented in the shell (ticket 0045)  
**Tickets:** [0045](../tickets.md) (shell), [0046](../tickets.md) (`window-layouts` consumer)  
**Depends on:** [Shell surface presets](./2026-08-23-shell-surface-presets.md), [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md)  
**Not this spec:** Liquid Glass; addons creating `NSWindow`; per-addon pixel or percent fields; rotating the physical display

## 1. Intent

The shell owns a **fixed catalog of view types**. A view type is a **viewport**: size band + panel aspect + chrome + dismiss rules. It is not an addon id and not a raw width/height.

**Portrait / landscape** means the **panel** is taller-than-wide or wider-than-tall. It does not mean the monitor rotated.

The **app** defines the types. Each **addon** lists the type **id(s)** it may use. Each **command** (or run `ui`) picks **one** id from that allow-list.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Count | **Ten** in-panel types. No eleventh size until a job proves the ten cannot host it. |
| Who chooses | Pattern/destination selects the type. Addon yaml names allowed ids; it does not invent geometry. |
| Pixels in yaml | **Forbidden.** Fractions and point clamps live in the shell size table. |
| Screen | Size against `visibleFrame` of the **screen the panel is on** (pointer screen at invoke, or the panel’s current screen). Never span displays. Never assume the built-in laptop panel. |
| Clamp | Apply **min and max points** after the fraction so 70% of a 49″ ultrawide is not a wall and 40% of a 13″ is not a stamp. |
| Morph | Same `KeyablePanel`, same stack. Frame morphs to the type’s rect; Reduce Motion snaps. |
| Interaction patterns | `toast` / `list` / `form` / `confirm` / … stay the **content** contract. View type is **geometry**. Defaults map patterns → types; `board` / `spread` / `canvas` / `grid` are explicit. |
| Not in the ten | `toast` (HUD), `status` (menu bar), `note` (detached), `veil` (full-screen overlay on one display). |

### Rejected

- Per-addon `width` / `height` / `percent` in yaml (still rejected; 0008).
- Always-on large hole with a small search inside.
- A second window that grows out of the palette.
- Free-resize of the keyable panel in v1.
- AeroSpace-style off-screen fake Spaces as a view type.
- iPhone-style “device rotated” layout system.

## 3. The ten types

| id | Aspect | Band (intent) | Chrome | Hosts |
|---|---|---|---|---|
| `seek` | wide, short | search strip | search only | Empty launcher |
| `palette` | wide > tall, small | search + rows | search + list | Launcher with rows |
| `ask` | wide, tiny | dialog | title, body, two actions | Confirms |
| `fields` | **portrait** | short form | labeled fields | Options, names, pickers with fields |
| `rows` | **portrait** | filterable list | search + rows | Ports, processes, clip history, apply-zone |
| `grid` | **landscape** | ~40% gallery | search + cards/icons | Catalog, emoji, screenshots |
| `board` | **landscape** | ~40% spatial | 2D layout | Snap board, week, world-overlap |
| `spread` | **landscape** | ~40–50% two panes | left/right | Diff, compare |
| `canvas` | **landscape** | ~70%, capped | sit-in content | Play, PDF page, OCR preview |
| `rail` | **portrait** | medium height, narrow | page / stack | Settings, addon detail |

Exact point table is an implementation detail of `ShellPreset` / a `ViewType` size function. Caps (illustrative, lock numbers in code + tests):

- `canvas` max ~1400×900 pt, min readable ~800×500 pt.
- `board` / `grid` / `spread` max width ~1100 pt.
- `rail` / `fields` / `rows` width capped ~520–560 pt even on ultrawide.
- Center the frame on the target screen; clamp to that screen’s `visibleFrame`.

### Default pattern → type

| Pattern / shell destination | Default view type |
|---|---|
| Launcher, no rows | `seek` |
| Launcher, with rows | `palette` |
| `catalog` | `grid` |
| `settings`, `detail` | `rail` |
| `confirm` | `ask` |
| `list` | `rows` |
| `form` | `fields` |
| `toast` / `status` | none (not a panel type) |
| `note` | detached (not a panel type) |

A response may set `"view": "board"` only if the addon allow-list includes `board`.

## 4. Click-outside

**Amended 2026-08-25** (see [launcher + catalog design §3](./2026-08-25-launcher-catalog-design.md)): click-outside is **not** a property of view type. A type is geometry only (size band + aspect + chrome) — behavior on click-outside is a separate, per-command/per-response config, because the same type (`canvas`) hosts both a launcher-adjacent catalog browse (wants dismiss) and a sit-in content viewer like Play/PDF (wants ignore). Baking behavior into type would force a type split for what is really an unrelated axis.

Each command (or run response) sets its own click-outside behavior: **dismiss** (hide, empty stack) or **ignore** (panel stays; Esc / Cmd+W pop or dismiss per stack rules). Default per type, overridable per command:

| Types | Default click outside |
|---|---|
| `seek`, `palette`, `ask`, `fields`, `rows`, `grid`, `rail` | **Dismiss** (hide, empty stack) — same as 0008 |
| `board`, `spread`, `canvas` | **Ignore** (panel stays). Esc / Cmd+W pop or dismiss per stack rules |

Cmd+Tab still does not count as click-outside (0008).

## 5. Manifest and protocol

Addon:

```yaml
view_types: [board, rows, fields, ask]
commands:
  - id: snap-board
    view: board
```

- `view_types` is an allow-list of ids from §3. Omit it → shell defaults only (`rows` / `fields` / `ask` as today).
- Command `view` must be in that list.
- Run JSON `ui.view` overrides the command default; must still be in the list. Unknown id → error, do not morph.

Unknown ids fail validation (`scripts/validate-addon.sh`) once 0045 implements it.

## 6. Multi-display

- Invoke: screen containing the pointer (or last screen that showed the panel).
- Morph while visible: use the panel’s current `NSScreen`, not `NSScreen.main`.
- A `board` on a portrait *monitor* is still a **wide-and-short panel** on that `visibleFrame`.
- A `rail` on an ultrawide stays **narrow**; it does not take 40% of 5120 px.

## 7. Per-addon view type assignment — LOCKED (2026-08-26)

Every real addon's `view_types` assignment, decided while auditing the whole app's surfaces (not per-addon guesswork — each mapped against the addon's actual command shape: read-only glance, filterable list, form-style setup, spatial layout, or detached scratchpad).

| Addon | View type | Notes |
|---|---|---|
| `battery-eta` | `rows` | Read-only status; kept as a panel rather than folded into toast-only, since a single value still reads fine as a one-row `rows` panel |
| `weather-bar` | `rows` | Same reasoning as `battery-eta` |
| `world-clock` | `rows` | Multiple zones = genuinely multi-row content, clearest `rows` case of the three |
| `brew-outdated` | `rows` | Filterable package list |
| `ports` | `rows` | Filterable list + kill action — the spec's own `rows` example |
| `clipboard-history` | `rows` | Filterable list — the spec's own `rows` example |
| `pomodoro` | `fields` | Duration/session setup before the timer runs |
| `keep-awake` | `fields` | Duration picker |
| `floating-note` | `note` | Detached, persistent scratchpad — not one of the ten in-panel types (§2) |
| `window-layouts` | `board` | 2D spatial snap layout — already declared in yaml |
| `nudges` | `rows`, `fields`, `ask` | List + setup + confirm — already declared in yaml |
| `ui-demo-confirm` | `ask` | Reference confirm pattern |
| `ui-demo-form` | `fields` | Reference form pattern |
| `ui-demo-list` | `rows` | Reference list pattern |
| `mic-mute` | **TBD** | Instant toggle, no content to browse — likely toast-only (no panel), pending a real toast redesign (toast currently has no visual design, only an old AppKit implementation) |
| `mute-all` | **TBD** | Same as `mic-mute` |
| `focus-toggle` | **TBD** | Same as `mic-mute` |
| `open-terminal-here` | **TBD** | Instant action, no content — same toast-only question |
| `paste-plain` | **TBD** | Instant action, no content — same toast-only question |

**Types with no current real-addon example:** `seek` / `palette` (occupied by the launcher itself, not an addon), `grid` and `spread` (no addon currently needs a gallery or two-pane compare view — left unoccupied, not a gap to fix).

## 7.1 Visual design status — most types undesigned, own epic

This section (and §3's ten types) locks **geometry only**. Beyond `seek`/`palette` (viewA) and `canvas` (viewB/detail view/Preferences) — all designed as part of the [launcher + catalog design](./2026-08-25-launcher-catalog-design.md) — no type in this catalog has a real visual mockup. That includes `toast`, whose current AppKit implementation was flagged as visually poor when raised during this audit; five addons (`mic-mute`, `mute-all`, `focus-toggle`, `open-terminal-here`, `paste-plain`) are instant actions with no content to browse and are strong toast-only candidates, but their view-type assignment in §7's table stays **TBD** until toast — and the rest of the undesigned catalog — gets a real design pass.

Tracked as its own epic, not scattered across individual addon/surface docs: [2026-08-26 view types visual design](./2026-08-26-view-types-visual-design.md) (ticket 0052).

## 8. Mapping to 0008 presets

0008 destinations stay (`launcher`, `catalog`, `settings`, …). View types are the **size/aspect function** those destinations (and addon UIs) call. Do not add a parallel `NSWindow`. New spatial jobs (`board`, `canvas`) are new destinations that reuse this catalog — they are not one-off frames.
