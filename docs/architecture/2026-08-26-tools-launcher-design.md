# Jugnu — tools launcher

**Date:** 2026-08-26
**Status:** In progress — findings only, to be reviewed, scope only. Raised while discussing what non-technical users need to run the app entirely from the UI (no hotkey knowledge required).
**Depends on:** [Launcher + catalog design](./2026-08-25-launcher-catalog-design.md) (viewA row1 gets a new button triggering this surface)

## 0. Purpose

A new icon-grid surface (macOS Dock / Android-homescreen style), opened via a new button in viewA row1 (alongside the existing prefs button). Gives non-technical users a visual, browsable way to find and run commands without knowing the Opt+Space hotkey exists or how to type a search query.

## 1. Findings carried forward

- **New row1 button confirmed** (this session): viewA row1 will get an additional button beyond the existing favorites/prefs, specifically to open the tools launcher.
- **Not yet decided: favorites relationship.** Should the tools launcher show the *same* favorited commands as viewA's row1, or maintain its own separate list/ordering? Raised, not resolved.
- **Not yet decided: additional chrome.** Likely needs its own buttons beyond an icon grid — "Help," "Quit," possibly others — not yet scoped. (Note: "Quit" may belong to the menu bar epic instead, or both — not decided.)

## 2. Open questions (not yet explored)

- Visual shape — which view type (from the locked ten, [view types](./2026-08-24-view-types.md)) does it use? Likely `grid` (landscape, ~40% gallery, "search + cards/icons" — currently unoccupied by any real addon, see [view types §7](./2026-08-24-view-types.md#7-per-addon-view-type-assignment--locked-2026-08-26)) but not confirmed.
- Favorites: shared list with viewA row1, or independent?
- Full content/action inventory: what belongs here beyond command icons — Help, Quit, About, links to Preferences/catalog?
- Relationship to first-run/onboarding (ticket 0004) — is the tools launcher part of what a new user is shown during the tour, or purely a later-discovery surface?
- Relationship to the [menu bar epic](./2026-08-26-menubar-design.md) — do the two surfaces share content, or stay fully independent?

## Related

- [Launcher + catalog design](./2026-08-25-launcher-catalog-design.md) — row1 button origin point
- [View types](./2026-08-24-view-types.md) — likely `grid` type, currently unoccupied
- [Menu bar epic](./2026-08-26-menubar-design.md) — related but separate surface
- [Ticket 0053](../tickets.md) — tracking row, points here
- Architecture index: [README](./README.md)
