# Jugnu — menu bar icon + dropdown

**Date:** 2026-08-26
**Status:** In progress — findings only, to be reviewed, scope only.
**Depends on:** [Shell design](./2026-08-22-shell-design.md) (menu bar mentioned but not designed)

## 0. Purpose

Vision.md and shell-design.md both mention a menu bar icon with a "quit / open palette / prefs" menu, but no visual design exists for the icon itself or its dropdown contents. For a first-time non-technical user, the menu bar icon is arguably the *most* discoverable entry point (visible immediately after install, no keyboard shortcut needed) — deserves real design attention, not just a functional stub.

## 1. Findings carried forward

- **Existing scope** ([shell design](./2026-08-22-shell-design.md)): quit / open palette / prefs — functional list only, no visual design.
- Split out as its own epic, separate from the [tools launcher](./2026-08-26-tools-launcher-design.md), even though the two surfaces may end up related (both are non-hotkey entry points) — kept distinct because the menu bar icon is system chrome (lives in the macOS menu bar itself, always-present) while the tools launcher is an in-app panel surface, different design constraints.

## 2. Open questions (not yet explored)

- Menu bar icon: visual design (glow-motif, per the app icon's own visual language? static?), states (does it ever change appearance — e.g. reflect an active/muted state, similar to how the favorites row does for stateful commands?)
- Dropdown contents: does it stay just quit/palette/prefs, or grow to include more (e.g. a shortcut into the tools launcher, recent commands, current addon states)?
- Does the dropdown duplicate the tools launcher's content, link to it, or stay intentionally minimal and separate?
- Relationship to first-run/onboarding (ticket 0004) — is the menu bar icon called out/highlighted during the onboarding tour, given it's the most persistent, always-visible entry point?

## Related

- [Shell design](./2026-08-22-shell-design.md) — existing (undesigned) menu bar mention
- [Tools launcher epic](./2026-08-26-tools-launcher-design.md) — related but separate surface
- [Ticket 0056](../tickets.md) — tracking row, points here
- Architecture index: [README](./README.md)
