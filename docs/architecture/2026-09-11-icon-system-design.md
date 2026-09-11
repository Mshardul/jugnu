# Jugnu — icon system (ticket 0051)

Supersedes [2026-08-26 icon system design](2026-08-26-icon-system-design.md) (findings-only). This is the locked design. Reference artifact: [docs/mockups/icon-sheet.html](../mockups/icon-sheet.html) — the canonical, living glyph sheet; this doc records the *rules*, the sheet shows the *result*.

## 0. Scope

App's-eye view only: the base icon library, the render rule, the construction spec, chrome glyph inventory, fallback defaults. **Not in scope** (split out during this ticket's discussion, own tickets):

- Which glyph each addon gets — [0075](../tickets.md), gated on addon consolidation ([0074](../tickets.md)).
- Whether addons should be clubbed/merged before assigning icons — [0074](../tickets.md).
- Updating other mockup files (launcher-catalog, etc.) to use these icons — [0076](../tickets.md) and whichever ticket owns each consuming surface ([0052](../tickets.md), [0067](../tickets.md), …).
- Shell-side Swift rendering implementation — a Step-3 downstream ticket once this design is approved.

## 1. Locked decisions

| Topic | Decision |
|---|---|
| Addon icon approach | **Recognizable glyph**, not abstract composition. A `mic-mute` icon looks like a mic; the family signal comes from treatment (tile, stroke, glow), not from the glyph shape itself. Chrome icons follow the same rule — one system, not two. |
| Base library | **Lucide** (ISC license, `lucide-icons/lucide`), pinned at **v1.45.0**. Chosen over Tabler (5,900 icons but denser drawing, crowds the glow treatment at 16–20px) and over any multi-weight set (adds an unneeded decision axis). Chosen for the long-term end-state — third-party addon authors reference one enforced style by name; Lucide's openness holds up at Jugnu's mostly-small render sizes (16/26/34px) better than denser sets. |
| Escape hatch | **None.** No addon ships custom icon art, first-party or third-party. An addon naming a glyph outside the bundled set (or naming none) falls back to one of the fixed defaults (§5). This is a deliberate simplification: no per-icon art review, no supply-chain surface from addon-bundled SVGs, one enforced visual system at any addon count. |
| Render model | **Composite at render time**, not pre-baked variants. One raw glyph file per icon (Lucide's own SVG, unmodified path data). The tile background, theme-tinted stroke, and glow are all applied live by the render layer (shell: SwiftUI; mockups: CSS). Zero new icon assets per theme preset or per light/dark mode — a new theme is a token change, not an asset regeneration. |
| Jugnu layer, applied to every icon, every state | 1) **Tile** — rounded-square background (radius per view-type/token). 2) **Stroke re-tint** — glyph stroke color bound to the active theme's icon-primary token (`currentColor`). 3) **Ember glow** — a warm drop-shadow bloom around the glyph itself (not a separate shape/badge), using the app icon's own gradient color language. Applied uniformly — chrome and addon icons alike, stateful and non-stateful alike. Off-states get a dimmer glow (matches the dimmer stroke), never zero glow. |
| On/off state | **Two distinct glyphs**, picked by name (`mic` / `mic-off`, `star` / `star-off`, `bell` / `bell-off`, …) — never an outline/fill toggle, never a slash applied by our render layer. Lucide already draws the "off" variant as its own composed icon (base shape + a baked-in diagonal slash) for nearly every stateful glyph category we need. Rejected: glow/dim-only (the original findings-file rejection — ambiguous, reads as "vaguely off" even for non-stateful icons); outline/fill toggle (works but Lucide's own `-off` convention is more standard and covers more cases uniformly); render-layer slash overlay (redundant — Lucide already ships this per-icon, no need to compose it ourselves). |
| Category icons | One Lucide glyph per catalog category — deliberately distinct from any glyph a member addon might also use, so a category icon never gets confused with an addon icon inside it. |
| Status-dot exception | The stateful **status-dot** (addon-card "running" indicator) stays a **plain filled circle**, not a Lucide glyph, and does **not** get the ember-glow treatment — a colored dot plus a colored glow is two competing signals for the same "is this active" meaning. This is the one deliberate exception to "glow on every icon." |
| Supply mechanism | Lucide SVGs vendored into the repo (exact path TBD at implementation time — Step 3), pinned to v1.45.0, updated as a deliberate version bump, not fetched at build or runtime. Fallback-default and logo art hand-authored/reused, same directory, same construction spec. |

## 2. Construction spec

Every icon in the system — Lucide-sourced or hand-authored fallback — must conform:

- **viewBox**: `0 0 24 24` (Lucide's native grid). Hand-authored fallbacks (if ever needed beyond §5) match this grid.
- **Stroke**: `stroke-width="2"`, `stroke-linecap="round"`, `stroke-linejoin="round"`, `fill="none"`, `stroke="currentColor"` — Lucide's own defaults, unmodified.
- **Tile**: rounded-square background, corner radius per the consuming surface's own token (e.g. `favTileRadius`/`resultIconRadius` already in `JugnuUI/DesignTokens.swift`) — this spec does not introduce a new radius token, it reuses what a surface already owns.
- **Glow**: `drop-shadow` filter on the glyph, ember gradient color (`--accent`, Firefly `#f5a623` family) at ~70% mix for "on"/default state, ~30% mix for "off"/dim state. Radius scales gently with icon size — exact per-size values are the shell implementation's responsibility to tune for legibility (matches the app-icon's own [size-ladder](../assets/jugnu-icon-size-ladder.md) precedent: don't naively scale one blur value across all sizes).
- **No fill shapes** beyond what Lucide's own icons already use (e.g. `star`'s single filled path) — the system stays stroke-based, matching Lucide's own single-style convention.
- **On/off pairing**: named `<glyph>` / `<glyph>-off` exactly as Lucide names them. An addon or chrome spot that needs a stateful pair but whose glyph has no natural Lucide `-off` counterpart is an open case, resolved when it's actually hit (0075 for addons).

## 3. Chrome glyph inventory (locked)

Full sheet: [icon-sheet.html](../mockups/icon-sheet.html), Clusters 1–7. Summary:

| Cluster | Glyphs |
|---|---|
| 1 — dismiss/nav | close (`x`), back (`arrow-left`), more (`more-horizontal`) |
| 2 — search/favorite | search (`search`), favorite (`star` / `star-off`) |
| 3 — status/badges | status-dot (plain circle, on/off — glow exception, §1), first-party/verified (`badge-check`), update-available (`arrow-up-circle`) |
| 4 — alerts/feedback | warning (`triangle-alert`), error (`circle-alert`), info (`info`), checkmark (`check`) — error and warning are distinct silhouettes, not just colors, for accessibility ([0055](../tickets.md)) |
| 5 — utility chrome | external-link (`external-link`), drag-handle (`grip-vertical`), preferences/gear (`settings`) |
| 6 — catalog categories | System (`cpu`), Clipboard (`clipboard`), Focus (`moon`), Info (`gauge`), Notes (`sticky-note`) |
| 7 — fallback defaults | default-addon (`package`), default-bundle (`layers`), default-helper (`wrench`), default-logo (app icon itself, not Lucide) |

This is the **closed, app-owned set** — grows only when a new chrome surface is designed (a new ticket's job), not with addon count.

## 4. Standing rule for future addon icons

Since the addon list is open-ended and growing (present + future, [0072](../tickets.md)/[0074](../tickets.md)/[0075](../tickets.md)), this ticket defines the **method**, not a fixed list:

1. Pick the Lucide glyph name that most directly represents the addon's job (nearest-match, not most-clever).
2. If the addon is stateful (has an on/off, active/inactive, or similar toggle), check whether Lucide ships a `<glyph>-off` counterpart. If yes, use it. If no, that specific gap is resolved case-by-case when hit (not designed for speculatively here).
3. Apply the construction spec (§2) and Jugnu layer (§1) — no exceptions, no per-addon custom treatment.
4. If no Lucide glyph fits at all, fall back to `default-addon` (§3, Cluster 7) — never custom art (§1, no escape hatch).

## 5. Fallback defaults

| Slot | Glyph | Used when |
|---|---|---|
| `default-addon` | `package` | Addon declares no `icon:`, or names one not in the bundled set |
| `default-bundle` | `layers` | A bundle ([0048](../tickets.md)) has no more specific art |
| `default-helper` | `wrench` | A shared helper ([addon-manifest.md#helpers](../addon-manifest.md#helpers)) needs a generic glyph |
| `default-logo` | [jugnu-icon.svg](../assets/jugnu-icon.svg) (unmodified) | Any slot needing the app's own mark, not a job-glyph — always rendered as its own finished composition (dark tile, not theme-re-tinted), never passed through the stroke/glow render layer |

## 6. Open items (downstream, not blocking this design)

- Exact drop-shadow blur/spread values per render size — implementation-time tuning, same pattern as the app icon's size-ladder.
- Which directory / SPM resource target vendors the Lucide SVGs, and whether the full 1,600-icon set is bundled or only referenced icons — Step 3 sizing question.
- Per-icon `icon_focus`-style manifest fields, if the glow ever needs positioning beyond "centered on the glyph" (current design: it doesn't — glow wraps the existing shape, no separate focal point needed, simpler than the original findings file's "declared focal point" idea).
- Any future Lucide version bump — deliberate, recorded here.

## Related

- [icon-sheet.html](../mockups/icon-sheet.html) — canonical reference sheet, all locked glyphs at real sizes, both themes
- [2026-08-26 icon system design](2026-08-26-icon-system-design.md) — superseded findings, kept for history
- [2026-09-11 visual design mockups](2026-09-11-visual-design-mockups.md) — parent epic (0068)
- [0051](../tickets.md), [0074](../tickets.md), [0075](../tickets.md), [0076](../tickets.md) — this ticket and its splits
- [jugnu-icon.svg](../assets/jugnu-icon.svg), [jugnu-icon-size-ladder.md](../assets/jugnu-icon-size-ladder.md) — app icon source art, visual-language precedent
