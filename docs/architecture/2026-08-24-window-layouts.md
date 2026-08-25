# Jugnu — window-layouts addon

**Date:** 2026-08-24  
**Status:** Approved — implemented (`addons/window-layouts`; ticket 0046)  
**Ticket:** [0046](../tickets.md)  
**Depends on:** [View types](./2026-08-24-view-types.md), [Shell design](./2026-08-22-shell-design.md) (Accessibility at addon use), [UI host + speed](./2026-08-22-addon-ui-speed-design.md)  
**Packaging:** one zip, id `window-layouts`. Folded prior layout-save ideas into **zones**. **No** `layout-undo`.

## 1. Job

First-party **window family**: snap the front window, tile two, jump Spaces, pin, Stage Manager toggle, named **zones**, lists (app windows, displays). Popup UI + speed are part of the job. Not a silent script runner. Not a yabai replacement.

## 2. Locked product

| Topic | Decision |
|---|---|
| Undo | **None.** No `layout-undo`, no restore stack. Wrong snap → snap again or apply a zone. |
| Occupancy | **Zones only.** Geometry. No “which apps.” Missing-app launch is out of scope. |
| Saved zones | At most **six**, user-named. Save snapshots current frames (apps discarded). |
| Seventh save | **Replace picker** (`rows`): choose which of the six to overwrite. Same name in the picker is just another replace. Delete and rename on that list. |
| Daily snaps | **Both** palette commands **and** a **snap board** (`view: board`). Same ops. |
| Multi-display zone | **One zone**, slots tagged **per screen**. Apply maps UUID then fingerprint; missing display → scale onto main `visibleFrame` and list the miss. |
| Storage | Per slot: display UUID + fingerprint (`visibleFrame` size) + **normalized** `x,y,w,h` in 0…1 relative to that screen’s `visibleFrame`. Floats, then round to device pixels on apply. Not a 1D “50% width” split. Not global pixels as source of truth. |
| Window set (save and apply) | Visible, non-minimized, non-fullscreen, each display’s **current Space**, front-to-back. Hidden Spaces are not in the snapshot. Extra windows stay; too few → fill from the front. |
| Native Sequoia tiles | Our set-frame **wins**. |
| Desktop name | **Jugnu-local** label keyed by Space UUID. Shown in **our** lists. We do not claim Mission Control’s strip changes. |
| Stage Manager | **Toggle on/off** only. No grouping API. |
| Space jump | Post the **system Space shortcuts** (Control+1… / Control+arrows). Do not open Mission Control to click. Do not disable SIP. |
| List Spaces | Private **read** CGS/SkyLight, isolated. If a symbol vanishes, degrade to “Desktop 1…N”. Snaps must still work. |
| Move window to Space / pin-top | Isolated **write** CGS, version-gated. Ownership refusal → **error that command**, not a SIP prompt. |
| Permission | Accessibility **on first use** of this addon, not at empty-shell first launch. |

## 3. Architecture (helper)

Compiled **`exec`** helper in the zip (Swift). No user Python. No SIP off. No Dock injection. No wrapping Rectangle. No AeroSpace off-screen workspaces.

| Layer | Mechanism | Promise |
|---|---|---|
| Place / arrange / displays / zones / board | Accessibility + `visibleFrame` | First-class |
| Chrome `AXEnhancedUserInterface` | Disable around set-frame (Rectangle pattern) | Snaps stay instant |
| AX no-op windows | Optional SkyLight **fallback for set-frame only** | Isolated |
| `_AXUIElementGetWindow` | Correlate AX ↔ `CGWindowID` | Allowed private |
| Space jump | System shortcuts | First-class, OS-owned |
| List Spaces / current Space | Private **read** CGS | Best-effort list |
| Move-to-Space, pin-top | Private **write** CGS | Error if OS refuses |
| Tiling module | Must **not** import SkyLight | A CGS break must not take down Left half |

Shell stays dumb: JSON `api: 1`, `list` / `form` / `confirm` / `board`. Window logic stays in the addon process.

State file under the addon state dir; `cleanup` removes it on uninstall.

## 4. View types (allow-list)

```yaml
id: window-layouts
view_types: [board, rows, fields, ask]
```

| Command / UI | View | Pattern |
|---|---|---|
| Snap board | `board` | spatial list of regions (shell `board` chrome; content from JSON items) |
| Left half, right half, quarters, center, fill-desktop, maximize, tile-two, … | default toast or instant; also reachable from the board | `toast` after move, or no panel |
| Apply zone / replace zone / app-windows / move-display (if >2) | `rows` | `list` |
| Save zone (name) | `fields` | `form` |
| Destructive extras if any | `ask` | `confirm` |
| Space jump | `rows` | `list` of Desktops (our names + index) |

Click-outside: `board` does **not** dismiss (view-types §4). `rows` / `fields` / `ask` do.

## 5. Commands (family; same zip)

Representative ids (same-shape siblings ship on this zip):

- Place: `left-half`, `right-half`, `quarters`, `center-window`, `fill-desktop`, `maximize`, `fullscreen-toggle`
- Arrange: `tile-two` (+ swap), `gather-windows`, `hide-others`, `minimize-all`, `show-desktop`
- Display: `move-display`
- Pick: `app-windows`
- Memory: `zone-save`, `zone-apply`, `zone-delete` / rename via list actions — **not** `layout-undo`
- Chrome: `pin-top`, `space-jump`, `stage-toggle`, `desktop-name` (Jugnu label)

`layout-save` as a separate product is **folded** into zone save. Do not ship a second zip.

## 6. Speed and permissions

Invoke → first chrome of `board` / `rows` within UI+speed budgets. Do not enumerate every window on every Space before first paint of a front-window snap.

If Accessibility is denied: plain error, menu-bar still works, no silent no-op.

## 7. Out of scope

- Undo stack
- Scenes / launch-missing-apps
- SIP off, yabai SA, wrapping Magnet/Rectangle
- Mission Control overlay for rename
- Stage Manager groups
- Scaffolding this addon in this documentation change
