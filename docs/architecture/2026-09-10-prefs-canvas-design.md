# Jugnu — Preferences canvas (rail + settings panes)

**Date:** 2026-09-10  
**Status:** Approved  
**Plan:** [2026-09-10 prefs canvas](../superpowers/plans/2026-09-10-prefs-canvas.md)  
**Ticket:** [0064](../tickets.md) (narrowed to this epic)  
**Product shell lock:** [launcher-catalog §3.4](./2026-08-25-launcher-catalog-design.md) + [mockup](./2026-08-25-launcher-catalog-mockup.html)  
**Depends on:** [Shell surface](./2026-08-23-shell-surface-presets.md) (`settings` / `canvas`), keep-current toggles ([0063](../tickets.md))  
**Not this epic:** Hotkeys UI ([0037](../tickets.md)), addon detail tabs / Installed list / gear ([0065](../tickets.md)), Open primary ([0066](../tickets.md)), prefs Permissions inventory (0054 B remainder), icon art ([0051](../tickets.md))

## 0. Purpose

Today’s Preferences is a flat scroll: enable/uninstall, theme, sound, first view, keep-current. That fights the locked product — prefs is **settings only**; catalog owns install/enable/uninstall. This epic ships the **canvas rail chrome** and migrates **real settings** into the right panes, end-to-end. Later epics add more rail rows and addon surfaces; each ships complete when started.

**Delivery rule:** once an epic starts, it delivers its scope fully (no hollow tabs). This epic therefore **omits** Hotkeys / Installed / Permissions rail rows until those epics add them with real content.

## 1. Epic map (related work)

| Epic | Ticket | Complete when |
|---|---|---|
| **Prefs canvas** (this doc) | [0064](../tickets.md) | Rail + Theme / Addons→Updates / General; catalog actions gone from prefs |
| Addon detail tabs | [0065](../tickets.md) | Overview / Commands / Settings; Commands has Run; Settings = Permissions + config; gear + prefs Installed → Settings |
| Open primary | [0066](../tickets.md) | Manifest `primary` + Open on card/detail (installed + enabled) |
| Hotkeys | [0037](../tickets.md) | Full list + rebind + collision; **adds** Hotkeys rail row to prefs |
| Prefs Permissions inventory | [0054](../tickets.md) B remainder | Addons → Permissions cross-addon granted/needed |

## 2. Scope

### In

- Preferences as `canvas`: header **Preferences** + ✕, left rail, content pane (same band / working size as Browse).
- Rail (this epic only): **Theme** · **Addons** (accordion → **Updates** only) · **General**.
- Default selection on open: **Theme**.
- Content:
  - **Theme** — presets, live preview, light/dark color editors (behavior from today’s `PrefsView`).
  - **Addons → Updates** — Jugnu version; Keep Jugnu current; Keep addons current; Check for Updates; registry URL caption.
  - **General** — sound toggle; empty-search first view (Blank / Recent / Favorites).
- Remove from prefs: enable/disable list, Uninstall, Install starter addons, Browse Catalog….
- Move prefs UI into **JugnuUI**; App wires callbacks / config saves (conventions + [0013](../tickets.md)).
- Preference-row pattern: label (+ optional one-line description) | control; `--border` dividers.
- Smoke + CHANGELOG + ticket updates.

### Out

- Hotkeys rail row or rebind UI ([0037](../tickets.md)).
- Addons → Installed / Permissions rows ([0065](../tickets.md), [0054](../tickets.md)).
- Detail tabs, gear, Open / `primary`, Commands Run ([0065](../tickets.md), [0066](../tickets.md)).
- Mandatory shared rail component with Browse (optional later cleanup).
- Mockup emoji/icon polish ([0051](../tickets.md) placeholders OK).

## 3. Information architecture

```
Preferences
├── Theme
├── Addons
│   └── Updates
└── General
```

Later epics extend without redesigning the shell:

```
Preferences                    (future shape)
├── Theme
├── Addons
│   ├── Installed              ← 0065
│   ├── Permissions            ← 0054 B
│   └── Updates                ← this epic
├── Hotkeys                    ← 0037
└── General
```

**Navigation:** ✕ / Esc / click-outside use existing `settings` stack pop/dismiss. No new dismiss rules. `pushSettings()` / menu-bar Preferences / shell-native Preferences command unchanged at the stack level.

## 4. Architecture

| Piece | Layer | Role |
|---|---|---|
| Selection model (e.g. `theme` / `addonsUpdates` / `general`) | Core or UI value type | Extensible enum; later cases added by later epics |
| `PrefsView` | JugnuUI | Header + rail + pane; preference rows; theme editors |
| Config mutations, Check for Updates | App | Closures / bindings into `PrefsView` — no `AppModel` inside JugnuUI |
| `ShellPreset.settings` | existing | Still `canvas`; morph/frame unchanged |

**Rail vs Browse:** prefs may use a prefs-specific accordion rail. Extracting shared chrome with `BrowseCatalogView`’s sidebar is not required for Done.

**Addons accordion:** only **Updates** as a child in this epic. Expanding Addons with a single child still matches §3.4 accordion behavior and leaves room for Installed / Permissions without a layout rewrite.

## 5. Acceptance

Done when:

1. Opening Preferences shows rail + one content pane (not the old flat all-in-one scroll).
2. Theme, Updates, and General each persist to `jugnu.yaml` as today.
3. No enable / uninstall / starter-install / Browse Catalog controls remain in prefs.
4. Rail has no Hotkeys, Installed, or Permissions rows.
5. `cd shell && swift test` green.
6. [shell-smoke.md](./shell-smoke.md) retargets Theme / sound / keep-current to rail paths; catalog owns former prefs lifecycle checks.

### Tests

- Rail selection switches panes; default is Theme.
- Existing save coverage for theme / sound / `first_view` / `keep_*` still holds (extend if bindings move).

### Non-goals

Visual polish parity with the HTML mockup; shared Browse/Prefs rail extraction; any invoke / Open / detail-tab work.

## 6. Docs / tickets (this epic)

- This design; implementation plan under `docs/superpowers/plans/`.
- Narrow [0064](../tickets.md); stub [0065](../tickets.md) / [0066](../tickets.md); remark [0037](../tickets.md) and [0054](../tickets.md).
- CHANGELOG Added line when code ships.

## 7. Amendments to prior locks

- [launcher-catalog §3.4](./2026-08-25-launcher-catalog-design.md) full rail (Theme / Addons→General·Permissions·Updates / Hotkeys / General) remains the **long-term** IA. This epic ships a **prefix** of that rail with only panes that have real settings.
- Mockup “Addons → General” auto-update row is **Updates** (keep-current), not a hollow General under Addons.
- Detail tab label **Permissions** → **Settings** (Permissions + addon config) is owned by [0065](../tickets.md), not this epic.
