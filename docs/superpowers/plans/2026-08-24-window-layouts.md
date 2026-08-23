# Plan: window-layouts addon (0046)

**Spec:** [2026-08-24-window-layouts.md](../../architecture/2026-08-24-window-layouts.md)  
**Depends on:** [0045 view types](./2026-08-24-view-types.md) at least `board` / `rows` / `fields` / `ask`  
**Status:** Spec approved — **do not scaffold until the user asks**

## Goal

One zip `window-layouts`: AX snaps + zone file (max 6, replace picker) + snap board + Space jump via system shortcuts. No undo. No SIP off.

## Slices (when implementing)

1. Compiled `exec` helper; Accessibility request on first use; front-window set-frame on `visibleFrame` (halves, center, fill, maximize).
2. Chrome `AXEnhancedUserInterface` workaround; tests with a fake geometry port.
3. Zone JSON schema, save/apply, six-cap replace `list`, per-slot screen fingerprint.
4. Snap board JSON items → `view: board`.
5. Space list (CGS read, degrade) + jump via Control+N shortcuts.
6. Isolated CGS write for pin-top / move-to-space; error path if refused.
7. `stage-toggle`; Jugnu-local `desktop-name`.
8. Manifest `view_types`, cleanup of state dir, registry row, packaging script.
9. Manual smoke: two displays, denied Accessibility, Stage Manager on/off.

Do not import SkyLight from the tiling module. Do not add `layout-undo`.
