# View/Page naming — discussion notes

**Status:** Draft — in-progress discussion, letters are placeholders pending real names. Not an implementation plan; no code changes made from this doc yet.

## Terminology (locked)

| Term | Meaning |
|---|---|
| **ViewType** | Skeleton only — size band (width/height formula) + aspect. No chrome, no dismiss-rule, no behavior. |
| **Page** | ViewType + actual content — a concrete named screen. Chrome (rail, tabs, etc.), dismiss-rule, and transitions (e.g. genie) are Page-level, not ViewType-level. |
| ~~UIPattern~~ | Retired. `list`/`form`/`confirm`/`note`/`card` are now just Pages on some ViewType — no separate pattern layer. |

## ViewTypes (letters are placeholders, not final)

| Letter | Was called | Width | Height | Notes |
|---|---|---|---|---|
| ViewA | `seek` + `palette` (merged) | `clamped(0.40×w, 480–560)` | boolean: `120` fixed (compact) / `clamped(0.40×h, 280–360)` (expanded) | One ViewType, height driven by a flag — not two separate types |
| ViewB | `canvas` | `clamped(0.70×w, 800–1400)` | `clamped(0.70×h, 500–900)` | Shared by multiple Pages (see below) |
| ViewC | (canvas-sibling, unnamed) | `clamped(0.55×w, 700–1150)` | `clamped(0.55×h, 420–750)` | Independent formula, not defined relative to ViewB |
| ViewD | `ask` | `clamped(0.28×w, 340–420)` | `clamped(0.20×h, 160–220)` | Stack-bound alert/confirm |
| ViewE | `toast` | fixed `320×52` | fixed `52` | Detached, self-timed (1.2–1.5s), non-interactive, anchored top-center |
| ViewF | `board` | `clamped(0.40×w, 640–1100)` | `clamped(0.40×h, 400–800)` | Was sharing `grid`'s band; now its own independent formula (numbers unchanged, ownership changed) |
| ViewG | `fields` | `clamped(0.35×w, 400–560)` | `clamped(0.32×h, 240–480)` | Restored — real shipped usage (window-layouts, nudges) |
| ViewH | `rows` | `clamped(0.32×w, 400–560)` | `clamped(0.45×h, 320–700)` | Restored — real shipped usage (window-layouts, nudges) |
| ViewI | (new — widget) | `clamped(0.20×w, 240–320)` | `clamped(0.15×h, 180–260)` | Small, glanceable widgets — distinct from ViewB games (bigger, animated/interactive) |

**Dropped from the original 10** (confirmed unused — no real addon manifest references them): `spread`, `rail`, `grid`.

**Correction during discussion:** `fields`/`rows` were briefly dropped by mistake (grep was too narrow — only checked a few raw-string locations, missed `addons/*/addon.yaml`). Restored as ViewG/ViewH once `window-layouts` and `nudges` manifests were checked directly and found to declare/use both.

## Pages (locked so far)

| Page | ViewType | Content states / notes |
|---|---|---|
| Home Page | ViewA (compact) | Empty or populated favorites row |
| Home with Search Page | ViewA (expanded) | Typing/results/did-you-mean states; fixed 5-row-slot results region |
| Catalog Page | ViewB | "All addons" browse — rail (scope+categories) + card grid. Chrome is Page-level. |
| Preferences Page | ViewB | Same ViewType as Catalog, different rail content (flat settings categories, no scope group) |
| Detail Page | ViewC | Smaller than ViewB. Genie open/close transition is Page-level behavior — other Pages can reuse ViewC without inheriting the transition. |
| (large `booth`-shaped Pages — games, single-video downloader) | ViewB or ViewC, whichever fits | Detached from stack, addon-owned freeform content. Not one fixed size — picks whichever ViewType matches its content's actual footprint, same as any other Page. |
| Toast Page | ViewE | Degenerate Page — no dismiss action, no stack, self-timed (1.2–1.5s) |
| First-Run Page | ViewC | Shown once on first launch. Own `NSWindow`, not the shared `KeyablePanel`. Starts with the app's default theme (no saved user theme exists yet at this point). |
| Play/game Pages — dice-roll, coin-flip, pick-one, eight-ball, fortune, number-guess, hangman, tic-tac-toe, memory, breathing, reaction-time | ViewB | Each its own Page on the biggest ViewType — full-bleed content/animation, no new ViewType needed. Confirms size stays uniform (ViewB), content varies freely per Page (same relationship as Catalog/Preferences sharing ViewB). |
| Widget Pages — stopwatch, chess-clock, world-clock, pomodoro, color-eyedropper, qr-clip | ViewI | Distinct category from Play/games — small, glanceable, often persistent, not full-bleed/animated |

## Not a Page

| Surface | Reason |
|---|---|
| Menu-bar dropdown (Open Palette / Preferences / Quit) | Native `NSMenu`, system-rendered — no geometry the shell owns or controls, so it can't be a ViewType/Page at all |

## Open items (not yet resolved)

- Letters (ViewA–H) are placeholders — real names still to be picked, later pass.
- `ViewType.shellDefaults` (currently `[.rows, .fields, .ask]` in code) needs updating to reference the renamed/restored types once naming is final.
- Toast/ViewE's relationship to the Page model is still loose — it doesn't behave like a navigable Page (no back/dismiss-to-previous, self-timed) even though it now has a ViewType letter.
- "What else?" — original open-ended item from the user, not yet fully enumerated. Still to cover: each addon's own page (deliberately deferred to last).

## Related

- [View types (viewport catalog) — original spec](../architecture/2026-08-24-view-types.md) — this doc supersedes several of its decisions (10→8 kept types, chrome moved to Page-level, dismiss-rule confirmed Page-level per its own 2026-08-25 amendment)
- [Launcher + catalog design](../architecture/2026-08-25-launcher-catalog-design.md) — origin of viewA/viewB/detail/preferences content, now reframed as Pages
- [Launcher-catalog-mockup.html](../architecture/2026-08-25-launcher-catalog-mockup.html) — visual reference used throughout this discussion
