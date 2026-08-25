# Jugnu — unified hand-drawn icon system

**Date:** 2026-08-26
**Status:** In progress — findings only, to be reviewed. Split out of [ticket 0051](../tickets.md) because the ticket had grown past a one-row-with-findings scope into a real epic (construction rules, template format, full glyph inventory, theming mechanism, on/off representation, per-icon supply pipeline). This file is where that epic's design work happens; the ticket row now just points here.
**Depends on:** [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) (glow-dot + trail motif, theme token system), [Launcher + catalog design](./2026-08-25-launcher-catalog-design.md) (surfaced the need — placeholder icons throughout viewA/viewB/detail view)

## 0. Purpose

Every icon in the app — per-addon icons (favorites row, catalog cards) **and** UI chrome icons (close, search, star, badges, and other small functional glyphs, currently emoji/text placeholders like ✕ and 🔍) — should be hand-drawn, share the app icon's own glow-dot + trail visual language, and re-tint per active theme (3 presets × light/dark), rather than arbitrary/mixed-source art (emoji, system symbols, fixed per-addon art). One unified system, not separate efforts for addon icons vs. chrome icons.

Not yet started as a full brainstorm — this doc captures findings and decisions already surfaced incidentally while designing other surfaces, so nothing gets lost. Treat everything below as **input to a future proper design pass**, not a locked spec.

## 1. Findings carried forward (LOCKED elsewhere, applies here)

These were decided while designing other surfaces ([2026-08-25 launcher + catalog design](./2026-08-25-launcher-catalog-design.md)) but constrain this epic's eventual design:

- **Stateful favorite icons (viewA row1) use two distinct icon assets per on/off state**, not a glow/dim treatment on one shared icon. Glow/dim was tried as a placeholder and rejected on UX grounds — too easy to misread as "off," especially for non-stateful commands (e.g. calculator) that never had state to show in the first place, since a plain non-glowing icon visually collapsed toward the "dim" end next to a genuinely-off glowing icon. Concretely: a stateful command like mic-mute needs a `mic-on` glyph and a separate `mic-off`/`mic-muted` glyph, not one `mic` glyph plus a brightness/glow modifier.
  - Tradeoff accepted knowingly: doubles per-command icon-authoring for stateful commands specifically (non-stateful commands stay single-icon) — the glyph inventory is therefore not uniform-count per command, and this epic's construction rules/template format need to accommodate that asymmetry.
- **Theme-reactive re-tinting is required**, not fixed bitmaps — icons must re-render (primary/secondary color swap) per the active `JugnuTheme` (3 presets × light/dark), reactively, likely vector/template-rendered against the active accent — same reactive-push mechanism already locked for theme colors ([product pass §4 D](./2026-08-23-palette-ui-product-pass.md)).
- **Visual language**: glow-dot + trail motif from the app icon itself ([product pass §3](./2026-08-23-palette-ui-product-pass.md)) — the whole app should read as one icon family, not mixed sources.
- **Scope is both addon icons and UI chrome icons** — a single unified decision (construction rules, template format, supply mechanism) covers both, not two separate icon efforts. UI chrome inventory known so far from placeholders already in use: close (✕), search (🔍), star/favorite (★), official/first-party badge, status dot, and others as they get placeholder-mocked in future surfaces.
- **Placeholders remain in use everywhere until this epic ships**: default app icon standing in for addon icons (favorites row, catalog cards), plain emoji/text glyphs for UI chrome. Other in-progress design docs (e.g. the launcher/catalog design) should keep using these placeholders rather than waiting on this epic.

## 2. Open questions (not yet explored)

- Icon construction rules — what makes an icon "in the family" (stroke weight, corner radius, viewBox, allowed shapes)?
- Template format — SVG with parameterized fills/strokes? A component-per-icon Swift/SwiftUI approach? Something else?
- Full glyph inventory — complete list of UI chrome icons needed across all surfaces, complete list of per-addon icon slots (including the on/off pairs from §1)
- Per-icon supply mechanism — who draws these, in what tool/format, how do they get into the build (checked-in assets vs. generated)?
- How the on/off pairing (§1) is expressed in whatever template/inventory format gets chosen — e.g. a naming convention (`mic-on.svg` / `mic-off.svg`) vs. a manifest-level pairing declaration

## Related

- [Ticket 0051](../tickets.md) — tracking row, points here
- [Launcher + catalog design](./2026-08-25-launcher-catalog-design.md) — where placeholder icon rules are defined for the interim
- [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) — glow-dot motif, theme token system
- Architecture index: [README](./README.md)
