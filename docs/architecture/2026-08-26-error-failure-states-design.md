# Jugnu — error & failure states

**Date:** 2026-08-26
**Status:** In progress — findings only, to be reviewed, scope only.
**Depends on:** [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) (locks the in-panel error mechanism), [Shell design](./2026-08-22-shell-design.md) (behaviors exist, no visual design), [shell-smoke.md](./shell-smoke.md) (behaviors verified as working, not as designed)

## 0. Purpose

Failure-path UI across the app — install failure, offline registry fallback, hotkey conflict, and other error states whose *behavior* is already locked/tested but whose *visual design* has never been done.

## 1. Findings carried forward

- **In-panel error mechanism already locked** ([product pass §-level finding](./2026-08-23-palette-ui-product-pass.md)): a failed follow-up (list selection, form submit) shows an error **inline**, inside the still-open panel, via a shared `PanelErrorBanner` component — panel never auto-dismisses to a toast on failure, so in-progress input/scroll state isn't lost. Mechanism locked; the banner's actual look is not designed.
- **Catalog install failure** ([addon catalog browse design](./2026-08-23-addon-catalog-browse-design.md)): "failure shows an inline banner with `UserFacingError` copy, not a toast" — same `PanelErrorBanner` component, mechanism locked, visual not designed.
- **Offline registry fallback** exists as a behavior (shell design, shell-smoke.md: "falls back to local `addons/` if offline") — no UI shown for what tells the user this happened.
- **Hotkey conflict** exists as a behavior (shell-smoke.md: "registration fails visibly; changing `shell.hotkey` in config or first-run ⌘Space opt-in recovers") — "fails visibly" is not further specified; no design for what that visibility looks like.
- **Copy/voice tone already locked** ([product pass](./2026-08-23-palette-ui-product-pass.md)): "warm but restrained," every shell-owned string reads like a human wrote it, raw system/error dumps must never leak through — applies directly to whatever error copy this epic designs.

## 2. Open questions (not yet explored)

- `PanelErrorBanner`: shape, color, icon, placement within a panel, dismiss behavior (auto-timeout? manual dismiss? persists until the underlying error clears?)
- Install failure: does the banner differ from the generic follow-up-failure banner, or is it the same component reused?
- Offline fallback: does the user see anything at all, or is it silent-and-successful (arguably fine if it "just works," but worth a deliberate decision rather than an omission)?
— Hotkey conflict: "fails visibly" — where? Menu bar icon change? A one-time notification? An inline message somewhere in prefs?
- Any distinction between transient errors (retry likely to work) and structural ones (won't work until the user changes something) — different visual treatment?

## Related

- [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) — `PanelErrorBanner` mechanism, copy tone
- [Addon catalog browse design](./2026-08-23-addon-catalog-browse-design.md) — install failure behavior
- [shell-smoke.md](./shell-smoke.md) — offline fallback, hotkey conflict, tested behaviors
- [Ticket 0055](../tickets.md) — tracking row, points here
- Architecture index: [README](./README.md)
