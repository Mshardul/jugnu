# Jugnu — visual design mockup set (epic 0068)

## 0. Purpose

Jugnu has ~25 design docs, but the visual layer is scattered: some surfaces have a
mockup (`seek` / `palette` / `canvas`, the launcher-catalog `.html`), most have
"findings only, to be reviewed" epics and no pixel-exact picture. This epic
produces **one pixel-exact HTML mockup for every screen a Jugnu user actually
sees** — the shell app and every implemented addon — a Figma substitute checked
into the repo.

Three phases (mirrors the repo's ticket flow):

1. **Inventory + tickets** — this doc plus the mockup-owning rows in [tickets.md](../tickets.md).
2. **Per-surface design finalization** — pick up each child ticket, brainstorm,
   lock the design. **Deliverable of each child ticket = the finalized
   `docs/mockups/` file(s) + a short design note** (in that ticket's own spec
   doc under `docs/architecture/`, or appended to the epic doc it already owns).
3. **Apply to codebase** — separate downstream implementation tickets, one per
   mockup or per small group, `Depends on` the phase-2 ticket that finalized it.

Non-goal: this epic does not touch Swift. It also does not re-open locked
*behavior* (navigation tree, view-type geometry, permission model) — only the
*look* within those locks.

## 1. Organizing principle (locked 2026-09-12)

**A mockup file is organized by product surface — what the user is actually
looking at — never by the shell's internal view-type geometry**
(`seek`/`palette`/`ask`/`fields`/`rows`/`grid`/`board`/`spread`/`canvas`/`rail`).
View type is an implementation detail of how one screen is built; it is not
what a mockup file is about. An earlier version of this epic organized tickets
and files around the ten view-type ids — that framing was retired 2026-09-12
after it produced two tickets ([0052](../tickets.md) and [0072](../tickets.md))
covering the same ground under different names (see [tickets.md](../tickets.md)
Remarks on both rows for the full account, including the correction after a
wrong "duplicate" claim).

**Two buckets, two directories, one ticket-shape per bucket:**

- **`docs/mockups/shell/`** — the app itself, not addon-specific. One file per
  real shell screen (§2 has the current list).
- **`docs/mockups/addons/`** — one file per addon, containing every real
  screen/state that addon has as sections within that one file (§3).
- **`docs/mockups/icon-sheet.html`** — stays loose at the mockups root; a
  cross-cutting reference (ticket 0051, Done), not part of either bucket.

**Cross-cutting concerns are not their own bucket.** Permissions UI (card
badge, detail panel body, pre-TCC explainer) and error/failure states
(`PanelErrorBanner`, crash/timeout/empty states) are not screens of their
own — they are elements that appear *on* other screens (a permission badge on
a catalog card, an error banner over a form). Their mockup content lives on
whichever screen actually shows them; the tickets that originated their design
findings ([0054](../tickets.md), [0055](../tickets.md)) keep those findings but
no longer own a mockup deliverable.

## 2. Shell mockups (`docs/mockups/shell/`) — 7 tickets, 7 screens

| Screen | Owning ticket | Status |
|---|---|---|
| Launcher — empty (`seek`), with results (`palette`), search-transition | [0052](../tickets.md) | In progress |
| Tools launcher — icon grid | [0053](../tickets.md) | In progress |
| Menu bar icon + dropdown | [0056](../tickets.md) | In progress |
| Catalog browse (scopes, accordion rail, cards) + addon detail (tabs) — hosts the permission badge/panel body ([0054](../tickets.md) findings) and error/empty states ([0055](../tickets.md) findings) these screens show | [0067](../tickets.md) | Not started |
| Preferences — rail + panes | [0069](../tickets.md) | Not started |
| Install / upgrade / keep-current / dependency / integrity-failure | [0070](../tickets.md) | Not started |
| First-run / onboarding | [0071](../tickets.md) | Not started |

Each ticket's Description in tickets.md is authoritative for exactly what that
screen's mockup covers — not restated in full here to avoid the two documents
drifting apart.

## 3. Addon mockups (`docs/mockups/addons/`) — 1 ticket, N files

**[0072](../tickets.md)** — one HTML file per addon, `Depends on`
[0074](../tickets.md) (addon clubbing/consolidation audit — the file list isn't
final until that settles which addons merge). Every implemented addon gets a
file, including:

- The 11 addons with real popup UI (multiple screens/states each, listed in
  the ticket).
- The 7 toast/CLI-only addons — a toast is a real screen too, just a small one.
- The 3 `ui-demo-*` reference fixtures (absorbed from the now-dropped
  [0073](../tickets.md)).

Exact per-addon screen breakdown lives in ticket 0072 itself, not duplicated
here — the addon list changes shape once 0074 lands, and maintaining the same
list in two places is how 0052/0072 drifted apart the first time.

## 4. Dimension reference

From [view types §3](2026-08-24-view-types.md). A shell-mockup file locks its
frame to the real point size for whatever view type that screen actually uses
internally — this table is a lookup, not something a mockup file is organized
around (see §1).

| id | Aspect | Representative mockup size (pt) |
|---|---|---|
| `seek` | wide, short | ~640 × 96 |
| `palette` | wide > tall | ~640 × 420 |
| `ask` | wide, tiny | ~460 × 180 |
| `fields` | portrait | ~460 × 560 |
| `rows` | portrait | ~460 × 600 |
| `grid` | landscape | ~900 × 560 |
| `board` | landscape | ~900 × 560 |
| `spread` | landscape | ~960 × 560 |
| `canvas` | landscape | ~1120 × 700 |
| `rail` | portrait | ~460 × 620 |
| `toast` | HUD | ~320 × 72 |
| `note` | detached | ~300 × 360 |
| `status` | menu bar | dropdown ~280 wide |

All sizes are against the pointer screen's `visibleFrame`, centered, clamped —
mockups assume a 1440 × 900 reference display.

## 5. Conventions for the mockup files

- **Self-contained.** Inline CSS/JS, no build, no external fetch.
- **Theme:** Firefly **dark** first; light variant only where a ticket calls
  for it.
- **Chrome:** addon screens render **inside** the shell panel chrome, not bare.
- **Icons:** the system locked in [icon-sheet.html](../mockups/icon-sheet.html)
  (ticket 0051, Done) — no emoji/text placeholders in new mockups.
- **Tokens:** `JugnuTokens` / Firefly values from
  [launcher-catalog design §4](2026-08-25-launcher-catalog-design.md) and the
  theme store. No per-mockup palettes.

## 6. Open items

- Exact point sizes per view type — locked in shell code + tests, not
  re-specified here.
- Whether an `index.html` contact sheet is worth adding once enough files
  exist under `shell/`/`addons/`.
- 0074's outcome reshapes the exact addon file list under 0072 — expect that
  ticket's scope to be revised once 0074 lands.

## Related

- [tickets.md](../tickets.md) — epic row 0068; shell-bucket rows 0052/0053/0056/0067/0069/0070/0071; addon-bucket row 0072; addon-clubbing dependency 0074; dropped rows 0072-history/0073 (see their own Remarks)
- [view types](2026-08-24-view-types.md)
- [shell surface presets](2026-08-23-shell-surface-presets.md)
- [launcher + catalog browse design](2026-08-25-launcher-catalog-design.md) (tokens, `seek` / `palette` / `canvas` mockups)
- [2026-08-25-launcher-catalog-mockup.html](2026-08-25-launcher-catalog-mockup.html)
- [icon system design](2026-09-11-icon-system-design.md) / [icon-sheet.html](../mockups/icon-sheet.html)
