# Jugnu — shell surface: one panel, presets, stack

**Date:** 2026-08-23  
**Status:** Approved  
**Ticket:** [0008](../tickets.md)  
**Depends on:** [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md) (patterns, shell-owned chrome), [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) (tokens, theming), [Addon catalog browse](./2026-08-23-addon-catalog-browse-design.md) (taxonomy, registry, install — **not** the titled `BrowseCatalogWindow`)  
**Out of scope here:** Liquid Glass / Tahoe material chrome (parked in [ideas.md](../ideas.md)); first-run rewrite ([ticket 0004](../tickets.md) — this spec only leaves a door); per-addon pixel sizes; addons creating their own `NSWindow`; background `progress` queue (later); Quick note **command** (backlog on `floating-note`; this spec only adds the host `persist` flag)

## 1. Why now

The invoke hotkey is a 560×360 launcher. Browse Addons and Preferences are separate titled windows. Confirm/list/form are more panels. The catalog therefore looks like a different, cheaper app. Manual smoke on 2026-08-23 made that obvious.

Addon UI host already locked: nested navigation stays inside one panel; addons do not spawn unmanaged windows. The shell’s own catalog and prefs broke that rule. This epic puts the **shell** on the same rule.

This **supersedes** ticket 0002’s locked “own resizable `BrowseCatalogWindow`.” Registry taxonomy, caching, install, and uninstall-confirm from 0002 stay. The chrome does not.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Surface | **One** `KeyablePanel`. The configured invoke hotkey (`shell.hotkey`) and menu **Open Palette** drive that same object. It **resizes and swaps its view** (views transform into each other). No second launcher. No titled catalog or prefs windows. |
| Owner | **One** host owns the panel, the stack, mapping, hotkey home/close, toast HUD, and opening detached `note`. Do not keep today’s split (`PalettePanelController` destroys itself on run; `UIHostController` opens another panel). |
| Mechanism | Named **presets** (size + layout + chrome). History is a **stack** of `(preset, view state)`. Frame morphs to the top preset; Reduce Motion **snaps**. |
| Preset key | **Pattern / shell destination**, not addon id, not raw width/height. `mic-mute` and `paste-plain` share toast; `clipboard-history` and `brew-outdated` share `list`. A job that doesn’t fit gets a **new pattern**, not a one-off size. Addons do not declare pixel sizes. |
| Tree | Push / replace / pop follow the **tree from `launcher`**, not whether the frame size changes. Same-preset follow-up **pushes** when it is a child (e.g. list drill-down). Siblings **replace**. See §4. |
| History — pop | Leave a **child** step: **Esc**, **Cmd+W**, **Cancel**, and natural finish of **that step** (Confirm on a confirm, Close on detail). Restore previous preset + size + **view state** (query, selection, scroll, catalog filters, first responder). Esc is pop, not home. No extra Back control (Esc is enough). |
| History — home | Invoke hotkey / Open Palette while **not** on `launcher`: stack becomes `[launcher]` — **fresh** initial view (configured `first_view`, empty query, search focused). Does **not** restore the previous launcher query. |
| History — close | Invoke hotkey / Open Palette while **on** `launcher`: hide, stack empty. Next invoke is a fresh `launcher`. |
| History — dismiss | **Click outside** the panel (desktop / other apps — not empty space *inside* the panel): hide, stack empty. Click-outside is **not** pop and **not** home. **Cmd+Tab** / resign-key is **not** click-outside; the panel may resign key but the stack stays until click-out, home, close, or pop-to-dismiss. |
| Esc at root | On `launcher`, Esc and Cmd+W **dismiss** (nothing to pop). |
| Already there | Opening a destination you are already on (menu Preferences while on `settings`; Browse Addons while on `catalog`) is a **no-op** except focus that view. |
| Hidden vs visible | Menu / `openCatalog` / `openSettings` build the same stack whether the panel was hidden. Shell destinations are always `[launcher, destination]`. |
| What does not leave the node | Install/Enable/Disable on a catalog **card** or on **detail** (card/actions flip in place). Sidebar, tags, search inside `catalog`. |
| Two chrome kinds | **In-panel** presets vs **detached** titled windows. Shell owns both. Addon never creates an `NSWindow`. Detached is a **class** (v1: `note`); later jobs that must sit on the desktop get a new pattern with detached chrome, not a size field. |
| Detached | User-resizable titled window. Opening one **resets** the launcher (don’t leave the panel behind). Invoke hotkey **while a note is open** shows a **new** launcher stack; the note stays. Uninstall/disable still tears the note down. |
| Note persist | `note` JSON carries `persist: true` (scratchpad: close / Cmd+S / Cmd+W save — today’s `open`) or `persist: false` (throwaway: close discards). The **Quick note** command itself is backlog on `floating-note`, not built in this epic. |
| Toast | Stays a **toast HUD**, not a stack node, not a titled window, not a resize. Does not dismiss the panel. Today `run` hides the palette — that changes. Branded as Jugnu (firefly template icon + message) and themed with the active `JugnuTheme` (Firefly / Phosphor / Rose Quartz, light/dark). Non-activating: does not steal search focus. Auto-dismiss (~1.2–1.5s; shorter with Reduce Motion). A new toast replaces the old one. Catalog install failures stay **in-content**, not this HUD. Theme change retints a visible toast. |
| Focus | **First arrival** at a preset: that preset’s default (search on `launcher` / `catalog` / `list`; Confirm on `confirm`; first field on `form`; first control on `settings`; primary action on `detail`). **Pop** restores the previous first responder, not “as if just opened.” Home is a first arrival at `launcher`. |
| First-run | Stays its own window until [0004](../tickets.md). This epic leaves `openCatalog` / `openSettings` (optional initial catalog state: category/tag). Until 0004, invoke hotkey may still open the launcher while the wizard is up. |
| Themes | Firefly / Phosphor / Rose Quartz tokens unchanged. Glass later. `settings` includes an **in-panel theme preview** (mini launcher / token strip) because settings *replaces* the launcher — live-reload of the real launcher is not visible at the same time. |
| Shell commands | Browse Addons and Preferences are **shell-native commands** (searchable, keyboard, Return) — mental model “mandatory addons,” **not** zips, **not** My Addons toggles. Yaml hide is [0012](../tickets.md). |
| Long jobs | A long job **holds the current view**. The user waits there. Leaving that view (Esc, Cmd+W, home, click-outside) **or** quitting Jugnu **cancels** the process and runs **cleanup**. `progress` is **not** a stack preset here. A later epic may queue jobs in the background and offer a view to cancel running work or open completed results. |
| Motion | Views morph like one object unfolding (size + position; search field as the stable anchor where both ends have search). **Not** Dock genie (that reads as minimize). Clamp the frame to the current screen’s `visibleFrame`. Destination **chrome** is on screen immediately (speed budgets in UI+speed §6); then content fills. Duration short (~200ms). Reduce Motion **snaps**. |

### Rejected (do not revive)

- Always-on catalog-sized frame with the launcher as a small view inside it — empty search still looks like a blank page in a large panel.
- A second window that “grows out of” the palette — still two windows and two focus targets.
- Per-addon width/height in yaml.
- Click-outside as pop.
- Invoke hotkey as dismiss-from-any-depth (home-or-close instead).
- Folding Floating Note into the panel (it stays detached).
- Glass chrome in this epic.
- Absorbing toast into the keyable panel as a banner — toast stays a HUD.
- Putting `progress` on the navigation stack in this epic.

## 3. Presets (v1)

| Preset | Size (start from today’s panels) | Chrome | Who |
|---|---|---|---|
| `launcher` | **Compact** when `first_view` is blank or recents/favorites are empty (search + shell commands; no empty results `List` filling the hole). **~560×360** when there are rows. | in-panel | Search + results. Browse Addons and Preferences are real command rows. |
| `catalog` | ~800×560 | in-panel | Sidebar + tag chips + search + card grid. 0002 taxonomy/filter/install rules still apply. |
| `settings` | ~520×560 | in-panel | Today’s Preferences content (theme **with preview**, first view, my addons, …). |
| `detail` | ~560×480 | in-panel | Addon detail: name, version, description, commands, same action row as the card. **No sidebar.** |
| `confirm` | ~380×180 | in-panel | Destructive confirm (addon follow-up **and** uninstall confirm). |
| `list` | ~420×360 | in-panel | Pickers. |
| `form` | ~400×240 | in-panel | Few fields. |
| toast | HUD ~320×52 | HUD | Side effect. Not a stack entry. See §2 Toast. |
| `note` | detached ~420×320 | detached window | Floating Note. Not a panel preset. `persist` true/false. |

`progress` / `status`: not presets here. `status` stays menu bar. Long jobs wait on the current view (§2).

## 4. Tree — push, replace, pop

```
launcher
├── catalog  ←replace→  settings     (siblings)
│     ├── detail
│     │     └── confirm (uninstall)
│     └── confirm (uninstall from card)
├── settings
│     └── confirm (uninstall from My Addons)
└── addon job (list | form | confirm)
      └── child steps of that job (list→list drill-down may push)
```

Toast is not a node. `note` is not a node (detached; panel resets).

**Push:** a **child** of the current node (launcher → catalog; catalog → detail; detail → uninstall confirm; list → confirm; list → nested list).

**Replace:** a **sibling** (catalog ↔ settings). **Browse Catalog…** inside settings **replaces** settings. Esc from that catalog goes to `launcher`, not back to Preferences.

**Do not push:** catalog sidebar / tags / search; Enable/Disable/Install on the current card or detail; toast; detached `note` (resets the panel instead).

**Idempotent:** already on `catalog` / `settings` → do not push a second copy.

Pop restores the previous entry’s view state. Example: list → confirm → Cancel/Esc → same list, same highlighted row.

Job finished with a toast: **pop** the finished child, then show the HUD on whatever is now top (usually `launcher`). Errors stay on the current node (in-panel banner), not a toast — except toast-only commands whose whole job is the HUD.

## 5. Worked sequences

```
launcher
  → Browse Addons          push catalog
  → click card body        push detail
  → Esc                    pop catalog (filters + selection kept)
  → Uninstall              push confirm
  → Cancel or Esc          pop catalog (or detail if that’s what you came from)
  → Confirm (uninstall)    pop; card now shows Install
  → Esc                    pop launcher
  → Esc                    dismiss

launcher
  → Preferences            push settings
  → Esc                    pop launcher

menu Preferences (panel hidden or on launcher)
                           stack [launcher, settings]; morph to settings

on catalog, menu Preferences
                           replace → settings (launcher still under)
  → Esc                    pop launcher   (not catalog)

on settings, Browse Catalog…
                           replace → catalog
  → Esc                    pop launcher

on settings, menu Preferences again
                           no-op; focus settings

on catalog, invoke hotkey  home → fresh launcher
on launcher, invoke hotkey close
click outside (any depth)  dismiss, stack empty

launcher
  → run clipboard-history  push list
  → pick row, follow-up confirm
                           push confirm
  → Confirm                pop list (then toast HUD if the job ended)
  → Esc                    pop launcher

launcher
  → run mic-mute           toast HUD; stay on launcher
  → Esc                    dismiss

launcher
  → run floating-note      reset launcher; detached note
  → close note             save if persist true; discard if persist false
  → invoke hotkey          new launcher; note stays

long job on list
  → wait on list
  → Esc / home / click-out / quit
                           cancel process; run cleanup
```

Install/Enable/Disable on `catalog` or `detail` **stay** on that node; buttons/labels update in place. Uninstall is the one that pushes `confirm`.

## 6. Mapping

Shell table: `default_ui_pattern` / response `ui.pattern` → preset, HUD, or detached.

| Pattern (today) | Chrome |
|---|---|
| (none) / toast | toast HUD |
| confirm | `confirm` (push if child) |
| list | `list` |
| form | `form` |
| note | detached window (`persist` true/false) |
| Browse Addons (shell command) | push `catalog` (replace if current is `settings`) |
| Preferences (shell command) | push `settings` (replace if current is `catalog`) |

A future detached job = new pattern + “detached” in this table, not an addon-supplied `NSWindow`.

**Door for 0004 (do not build first-run here):** `openCatalog` / `openSettings` → `[launcher, destination]`, morph, first-arrival focus. `openCatalog` may take optional initial view state (category / tag, e.g. `recommended`).

## 7. View state (v1 snapshots)

Enough to restore on pop. Not a public addon API.

| Preset | Snapshot |
|---|---|
| `launcher` | query, selection, scroll, `first_view` contents |
| `catalog` | category, subcategory expanded, tags, query, scroll, selected card |
| `settings` | scroll, focused control |
| `detail` | which addon |
| `list` | query, highlighted row, scroll |
| `form` | field values, focused field |
| `confirm` | — |

## 8. What stays in tickets (not this spec)

These are slices or bugs; they must not be dropped, but they are not the surface model:

- [0005](../tickets.md) — shell commands as real rows; compact `launcher` when empty.
- [0006](../tickets.md) — catalog state/errors/gestures/reload on `catalog`/`detail`; uninstall confirm **pushes**.
- [0007](../tickets.md) — visual pass on in-panel `catalog`/`detail` (not the old titled window).
- [0009](../tickets.md) — first press of `shell.hotkey` must key the panel and focus search. **Must hold for home-or-close;** ship in the 0008 PR unless this lands first.
- [0010](../tickets.md) — tag chips only for tags present in the current category/filter set.
- [0011](../tickets.md) — `recordRecent` on every run; `first_view` only chooses empty-search contents.
- [0012](../tickets.md) — yaml can hide the shell-native Browse Addons / Preferences commands; not a My Addons toggle.

Quick note (`persist: false` command) lives on **floating-note** in [backlog.md](../backlog.md), not a ticket in this set.

## 9. Success criteria

1. One panel for launcher, catalog, settings, detail, confirm, list, form. Extra windows only for detached `note` and first-run (until 0004).
2. Navigation matches §4: push child, replace sibling, pop restores view state + first responder. Follow-up size is a consequence of the preset, not the rule.
3. Invoke hotkey / Open Palette: not on `launcher` → fresh home; on `launcher` → close. Click-outside dismisses. Cmd+Tab does not. Esc/Cmd+W pop (dismiss on `launcher`).
4. Compact `launcher` when there are no result rows; ~560×360 when there are. Morph is a size/position unfold, clamped to `visibleFrame`; Reduce Motion snaps. Destination chrome meets UI+speed first-paint budgets.
5. Toast is a Jugnu-branded, themed HUD; does not dismiss the panel; does not steal focus. Catalog install errors stay in-content.
6. `note` is titled/resizable; launcher is gone after it opens; persist true saves on close; persist false discards. Invoke hotkey while note is open shows a new launcher.
7. Browse Addons and Preferences are shell-native commands into `catalog` / `settings`; menu Preferences uses the same `settings` preset; catalog ↔ settings replace. Settings shows a theme preview.
8. Long jobs wait on the current view; leave or quit cancels and runs cleanup.
9. `openCatalog` / `openSettings` exist for 0004 (optional catalog initial state).
10. 0002 registry/install/taxonomy behavior is unchanged; `BrowseCatalogWindow` / prefs `NSWindow` are gone.
11. Tickets 0005–0007, 0009–0012 stay tracked until done. First hotkey press (0009) works.

## Related

- [Vision — Surfaces](../vision.md)
- [Addon catalog browse](./2026-08-23-addon-catalog-browse-design.md) — taxonomy/install still apply; titled window superseded
- Tickets: [0008](../tickets.md) (this epic), [0002](../tickets.md) (registry)
- Backlog: [floating-note / quick-note](../backlog.md)
