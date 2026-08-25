# Jugnu — permissions, privacy & security

**Date:** 2026-08-26
**Status:** In progress — findings only, to be reviewed, scope only.
**Depends on:** [Shell design](./2026-08-22-shell-design.md) (permissions table exists, no UI), [Ticket 0038](../tickets.md) (pre-install permissions disclosure), [Launcher + catalog design §3.3](./2026-08-25-launcher-catalog-design.md) (detail view's Permissions tab is a landing spot for this data, not its design)

## 0. Purpose

Everything touching permission requests, privacy disclosure, and security-relevant UI across the app, gathered into one epic since these concerns recur at several points (install-time disclosure, runtime OS permission prompts, addon detail view's Permissions tab, first-run) and should be designed once, consistently, rather than piecemeal per surface.

## 1. Findings carried forward

- **Shell design has a permissions table** (`shell/Sources/...` referenced, section "Permissions" in [shell design](./2026-08-22-shell-design.md)) listing *when* each permission is needed, but no UI has been designed for how a request/explanation is actually shown to the user.
- **"Honest permission UX"** is named as a v0 goal in shell design's testing/acceptance section — intent locked, no design.
- **Ticket 0038** already exists for pre-install permissions disclosure — this epic should absorb/coordinate with it rather than duplicate.
- **Detail view's Permissions tab** ([launcher + catalog design §3.3](./2026-08-25-launcher-catalog-design.md)) is locked as a structural placeholder — "required-permissions list" — content/format not designed, deliberately deferred to wherever permissions UI gets its real design (this epic).
- **Hotkey permission fallback already locked** (shell design): "If hotkey permission missing: menu bar Open palette still works" — a real precedent for graceful-degradation pattern this epic should follow elsewhere.

## 2. Open questions (not yet explored)

- What does an in-app permission request/explainer screen look like, before or alongside the native macOS system prompt?
- Pre-install disclosure (ticket 0038): shown where — inline on the catalog card, in the detail view, as a separate step in an install flow?
- Detail view Permissions tab: what does a permission list item actually look like (icon? severity/risk indication? plain text?)
- Revocation/changed-permission handling: what happens if a user revokes a permission after an addon is already installed and using it?
- Any app-wide privacy statement/surface (e.g. "what does Jugnu ever send off this Mac") — likely "nothing," but worth having a designed place to say so, not just an absence.
- Security-relevant iconography — ties into [ticket 0051's icon system epic](./2026-08-26-icon-system-design.md), since permission-related icons need to read as trustworthy/serious, not playful.

## Related

- [Shell design](./2026-08-22-shell-design.md) — existing permissions table, no UI
- [Launcher + catalog design §3.3](./2026-08-25-launcher-catalog-design.md) — detail view Permissions tab, structural placeholder
- [Ticket 0038](../tickets.md) — pre-install permissions disclosure (existing, related ticket)
- [Ticket 0054](../tickets.md) — tracking row, points here
- Architecture index: [README](./README.md)
