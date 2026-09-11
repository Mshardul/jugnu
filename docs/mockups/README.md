# Mockups

Pixel-exact HTML mockups of every screen a Jugnu user actually sees — the shell
app and every implemented addon. Figma substitute, checked into the repo.

Governed by the epic:
[docs/architecture/2026-09-11-visual-design-mockups.md](../architecture/2026-09-11-visual-design-mockups.md)
(epic **0068** in [docs/tickets.md](../tickets.md)).

## Structure

```
docs/mockups/
  icon-sheet.html   — icon system reference (ticket 0051), consumed by both buckets below
  shell/            — the app itself: menu bar, launcher, catalog, prefs, permissions,
                      install/upgrade, first-run, errors, tools launcher, generic chrome
  addons/           — one file per addon, every real screen/state that addon has
```

**Two buckets, not one file per view-type.** A mockup is organized by *product
surface* (what the user is looking at), never by the shell's internal view-type
geometry (`rows`/`fields`/`ask`/…) — view type is an implementation detail of
how one screen is built, not what a mockup file is about.

- **`shell/`** — one file per shell product area (see the epic doc for the
  current file list and what's inside each).
- **`addons/`** — one file per addon (post any consolidation from
  [0074](../tickets.md)), containing every real screen/state that addon has as
  sections within the one file — not split across multiple files per addon.

## Rules

- Self-contained: inline CSS/JS, no build, no external fetch.
- Each screen locks its frame to the real point size the shell renders it at.
- Firefly **dark** palette first; light variant only where a ticket calls for it.
- Addon screens render **inside** the shell panel chrome, not bare.
- Icons use the system locked in [icon-sheet.html](icon-sheet.html) (ticket
  0051, Done) — no more emoji/text placeholders in new mockups.

Each child ticket under epic 0068 delivers its `.html` files here as it is
picked up.
