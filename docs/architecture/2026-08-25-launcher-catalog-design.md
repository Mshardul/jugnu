# Jugnu — launcher + catalog browse design

**Date:** 2026-08-25
**Status:** In progress — living doc, decisions appended as brainstorming continues
**Depends on:** [Shell design](./2026-08-22-shell-design.md), [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md), [View types](./2026-08-24-view-types.md), [Shell surface presets](./2026-08-23-shell-surface-presets.md)
**Living mockup:** [2026-08-25-launcher-catalog-mockup.html](./2026-08-25-launcher-catalog-mockup.html) — visual reference kept in sync with each locked section, Firefly dark theme only
**Related open ticket:** [0002](../tickets.md) — addon management / Preferences redesign + catalog browse (this doc is that design)

## 0. Purpose

Design for the Opt+Space launcher surface (**viewA**) and the "see all addons" catalog browse surface (**viewB**), building on top of the already-approved token/theme system ([2026-08-23 product pass](./2026-08-23-palette-ui-product-pass.md)) and the ten-type view catalog ([2026-08-24 view types](./2026-08-24-view-types.md)). This doc records decisions as they're locked during brainstorming, not all at once — sections get filled in and approved incrementally.

## 1. Surface map (locked so far)

| View | Trigger | Shape | Status |
|---|---|---|---|
| **viewA** | Opt+Space | Very-small-height, medium-width. Row1 + Row2 only. | Locked (§2) |
| **viewB** | "See all addons" button in viewA | ~60% screen width × ~60–70% screen height on a 13–16" MacBook (exact fraction/clamp TBD — see open questions). Row1 + Row2 (same as viewA) + category/subcategory/list region below. | Locked (§3) |
| Search results (typing in viewA's row2) | User types in viewA | viewA grows downward in place (same panel, morphs — see §2.1) | Locked (§2.1) |
| Preferences (from viewA's prefs button) | Click "all addons + prefs" | Not yet designed — likely `rail` per existing view-type catalog | **Open** |

**Mapping to the existing [view types](./2026-08-24-view-types.md) catalog — LOCKED:**

| Surface | Type | Why |
|---|---|---|
| viewA, empty | `seek` | wide, short, search-only chrome — exact fit |
| viewA, search results (§2.1) | `palette` | wide, small, search+rows — exact fit |
| viewB (catalog browse) | `canvas` | landscape, ~70% capped, "sit-in content" band (max ~1400×900, min ~800×500) fits viewB's 864×585 mockup better than `grid`'s ~40%/~1100pt-max band, which was sized for a pure card gallery, not rail+tags+grid combined |
| Detail view (§3.3) | `canvas` | same band; stacks on top of viewB rather than replacing it, still a landscape sit-in-content surface at a smaller size within the same type's range |

No 11th type needed — resolves the open reconciliation question. `canvas`'s spec default for click-outside is **ignore**, but per the [view-types §4 amendment](./2026-08-24-view-types.md#4-click-outside) (click-outside is now a per-command override, not fixed by type), viewB and the detail view both **override to dismiss** — they're launcher-adjacent catalog browsing, not sit-in content like Play/PDF, and should behave like the rest of the launcher flow.

**Why override matters (concrete case) — LOCKED reasoning:** `canvas`'s "ignore" default exists for its original use case — sit-in content like Play or a PDF viewer, where a user alt-tabs away to reference something else and expects the panel still there, undisturbed, on return. viewB/detail are the opposite: a quick in-and-out picker, where clicking away signals "done browsing" and an un-dismissed panel would feel stuck. Same type, opposite interaction expectation — this is exactly why click-outside had to become a per-command override rather than a fixed property of `canvas`.

**Closing the stack — LOCKED:**
- **viewB** (no detail open): click-outside dismisses (override above) · Esc also dismisses · no explicit ✕ in chrome (none needed — row1 has no close button, matches viewA's own dismiss-by-click-outside convention).
- **Detail view** (stacked on viewB): explicit **✕** in its header closes it, returning to viewB · Esc pops just the detail view (same as ✕) · **clicking the dimmed viewB background behind the detail view pops only the detail view**, not the whole stack — one step at a time, consistent with Esc/✕ rather than a fast full-exit. Reaching viewA from here takes a second click-outside (now against viewB itself) or Esc again.

**Closing summary across all `canvas` surfaces — LOCKED.** Three primitives (click-outside, Esc/Cmd+W, an optional in-chrome ✕) exist type-wide; each surface wires them per its own interaction model, not a fixed `canvas` default:

| Surface | click-outside | Esc / Cmd+W | Own ✕ |
|---|---|---|---|
| viewB | dismiss | dismiss | no (matches viewA's no-✕ convention) |
| Detail view | pop (just detail, §above) | pop (just detail) | yes (mocked, header) |
| Generic `canvas` (Play, PDF preview — the type's original use case) | ignore (no-op) | dismiss | addon's own choice, not mandated by the type contract |

## 2. viewA — launcher (Opt+Space)

Two fixed rows, no query-dependent third region designed yet.

**Row1:**
- Float left: Jugnu logo (glow-dot mark, per the icon design in the [product pass spec §3](./2026-08-23-palette-ui-product-pass.md))
- Center: **favorites row — LOCKED.** User maintains a reorderable list of favorited commands (any type — boolean toggles, forms, panels, anything with a command id). Row1 shows the **top 5** by that order, plus a 6th "…" icon.
  - **Click behavior:** identical to running the command normally through search — a toggle flips, a form opens, a confirm asks, a panel opens. The favorite icon is a shortcut to the command, not a separate restricted execution mode. No category of command is excluded from being favoritable.
  - **State display:** for commands with an on/off or similar live state (mic mute, DND, dark mode), the icon visually reflects current state — dimmed/dark = off, lit/glowing = on, reusing the icon's own firefly glow motif (dark speck vs. lit glow) rather than a separate badge/dot convention. Commands with no meaningful state (calculator, calendar) show a plain icon, no forced state indicator. Mocked up in the [living mockup](./2026-08-25-launcher-catalog-mockup.html) (`.fav.lit` / `.fav.dim`).
  - **"…" icon:** opens viewB with **Favorites** pre-selected as the active **scope** (§3.1) — not a new dedicated view.
  - **Row1 editing — LOCKED, second entry point alongside the card star (§3.2).** Row1 supports direct **reorder** and **remove** of its existing favorites, without needing to open viewB:
    - **Reorder:** drag-and-drop directly within row1's visible slots — immediate, matches dock/launcher icon-reorder conventions.
    - **Remove:** right-click a favorite icon → "Remove from Favorites" in a small context menu. Chosen over drag-to-remove — explicit action, no risk of an errant drag accidentally unfavoriting something.
    - **Adding a new favorite is card-star-only, deliberately not supported from row1.** Explored a compact add-from-row1 picker (small anchored dropdown, or row2 morphing into a picker) and rejected it — row1 stays purely a reorder/remove surface for what's already favorited; adding new ones goes through the card star in viewB, avoiding a second, narrower "add" UI to design and keep in sync with the card's own favoriting flow.
    - Both reorder and remove done in row1 stay in sync with viewB's Favorites-scoped list (§3.1) — same underlying favorited-commands order, just two places to view/edit part of it.
  - **Empty state (0 favorites) — LOCKED: blank center, no substitute content.** Row1 keeps its fixed geometry (logo left, prefs right) in every state — center is simply empty when there are no favorites, rather than filling with a text prompt, a repeated "JUGNU" wordmark, or ghost/dashed placeholder slots. Explored and rejected: a muted text prompt (breaks row1's all-icon visual rhythm) and repeating the brand name centered (the logo already lives left-aligned per §2 — a second, centered wordmark only in the zero-state means row1's layout visibly reflows between empty and populated states, the same geometry-inconsistency problem as collapsing the row). Blank is a one-time first-run cost, not a recurring one, and adds no new element needing its own design/consistency decisions.
- Float right: "view all addons + preferences" button

**Row2:**
- Wide search bar (slightly narrower than viewA's full width), placeholder text rotates through real installed commands (already speced in [product pass §4.A](./2026-08-23-palette-ui-product-pass.md) — "Try 'mute mic'…" pattern)

### 2.1 Search-results transition — LOCKED

Typing in Row2 does **not** swap viewA out for a different view. The same panel **grows in place once, to a fixed height**: Row1 and Row2 stay exactly where they are (favorites/logo/prefs remain visible and clickable the entire time, never hidden to make room), and a results region appends below Row2, using the existing `morph` mechanism already locked in [view types §2](./2026-08-24-view-types.md) (same `KeyablePanel`, frame morphs to the new size, Reduce Motion snaps instead of animating). This also matches [ticket 0005](../tickets.md)'s already-shipped "compact when empty" behavior — same principle, opposite direction (grows when there are rows instead of just avoiding an empty expanded state).

**Results region — LOCKED: fixed 5-row-slot window, does not resize per query.** Reopened from an earlier draft that had the panel grow/shrink to match result count — rejected once actually considered, because a panel that keeps resizing while the user is still typing (each keystroke narrowing or widening the query) feels unstable, not glanceable. Instead:

- The results region always reserves **exactly 5 row-slots** of height the moment there's ≥1 result — same outer panel height whether there's 1 result or 20. Row1/Row2 never move; only this fixed-size region appears/disappears below them.
- **Slot 5 is always reserved for a "Show all addons →" link** (opens viewB) — not a real result row, fixed position regardless of how many real results exist. If there are 4 or fewer real results, slots between the last real result and slot 5 stay **blank** (reserved empty space, not collapsed) — slot 5 does not slide up to sit immediately after the last result.
- If there are more than 4 real results, slots 1–4 show results and the region **scrolls internally** to reach the rest — slot 5's "Show all addons" is not shown in this case (no room, and it would compete with actually scrolling to see more real results).
- Exactly 4 real results fills slots 1–4 with slot 5's "Show all addons" still visible, no scroll.

**Zero real results — LOCKED.** Falls back to the already-shipped "did you mean" behavior ([product pass §4.A](./2026-08-23-palette-ui-product-pass.md)): the single closest-matching command by fuzzy score, shown as a soft suggestion instead of a flat "no results." **Scoped to installed addons only** — a suggestion pointing at an uninstalled addon's command isn't immediately actionable (the user would have to install it first, which isn't what "did you mean" implies), so the candidate pool for this fallback excludes anything not installed. Slot 5's "Show all addons" link still shows below the suggestion — it remains the path to the wider catalog if the installed-only suggestion isn't what the user wanted.

**Result row content — LOCKED:** icon (same icon-chip visual language as favorites/cards elsewhere), command name (primary), parent addon name (secondary, disambiguates when multiple addons have similarly-named commands) — matches the source-context convention of Alfred/Raycast-style launchers. Ranking/matching itself (fuzzy subsequence, tiered by field) is already locked in [product pass §2](./2026-08-23-palette-ui-product-pass.md) — this section only adds the row's content fields, not new ranking behavior.

**Result row visual style — LOCKED: breadcrumb.** Icon (left) + one continuous text line reading "Addon › Command" — addon name muted (`textSecondary`), separator, command name bold/primary (`textPrimary`). Explored 6 options: pill/tag (addon as a colored chip before the command), breadcrumb (chosen), table-column (command left, addon right-aligned), mini-card (each result as its own bordered chip, closest visual kinship to catalog cards — runner-up, rejected in favor of breadcrumb's faster single-line scan), full-height icon column, and monogram-badge-with-stacked-label. Selected row highlighted via background tint (full row, not just an accent bar).

## 3. viewB — catalog browse ("see all addons")

**Dimensions — LOCKED: `canvas` type.** Uses the `canvas` view type's own size band (~70% capped, max ~1400×900pt, min readable ~800×500pt per [view types §3](./2026-08-24-view-types.md)) rather than a viewB-specific fraction — no new size table needed. Mockup's 864×585pt (60%×65% of a 1440×900 viewport) sits comfortably inside that band and remains the working reference; exact point table is `canvas`'s existing implementation detail, not re-specified here.

**Structure:**
- Row1 + Row2 identical to viewA, fixed at top
- Below: categories / subcategories / addon list region

**Layout — LOCKED: Option C (combined accordion rail).**

Explored options A (two vertical rails — categories | subcategories | list), B (categories as horizontal pill tabs — rejected, read as a tag filter not serious category nav), C, D (single category dropdown + subcategory chip row — rejected, requires a new dropdown component/view the user doesn't want), E (flat categories rail + subcategory tab strip — runner-up, rail never reflows but splits nav into two zones), F (icon-only dock with fly-out subcategories — rejected as the *only* nav option, though a future minimize/collapse affordance on top of C is worth keeping in mind), G (no nav chrome, pure scrolling outline with sticky section headings — rejected, users won't find categories buried at the bottom of a long scroll), H (search-bar-as-navigator with removable category/subcategory chips — rejected).

**Option C, locked:** one rail on the left. Categories are a flat vertical list; clicking a category expands it in place (accordion) to reveal its subcategories nested directly beneath, indented. Rail height grows/shrinks per selection — accepted tradeoff for keeping everything in one visual column instead of splitting nav across two regions (rail + separate tab strip, as in E).

**Row entry visual treatment — LOCKED (rail-polish v2):**
- Category row: small icon chip (rounded square, category-specific icon) + label. Active category gets a left accent bar (3px, accent-colored, positioned just outside the row) + tinted background + tinted icon chip.
- Subcategory rows: nested under the expanded category, indented ~28px, with a thin 1px vertical line (accent-neutral, `--border` token) as the indent guide — replaces an earlier ASCII `└` connector glyph, which read as visually "weird."
- Subcategory text color: **not** `--textSecondary` (too low-contrast against `--background` for a primary nav label the user needs to read at a glance) — needs its own brighter token, tentatively `--sub-text` (~`#B8AF9E` on Firefly dark, i.e. roughly halfway between `--textSecondary` and `--textPrimary`). Selected subcategory still uses `--accent`.

### 3.1 Scope (All / Installed / Recent / Favorites) — LOCKED

Raised mid-discussion: viewB shouldn't treat Favorites as a one-off pseudo-category bolted onto the Categories rail. Resolution: **scope entries are just more rows in the same rail list**, not a separate control region — no second always-visible selector, no combinability mechanism to build. The rail becomes one flat list with two visually-grouped sections, reusing the exact row treatment already locked in §3 (icon chip, left accent bar when active):

1. **Scope group** (top): **All** (default-active, pre-selected on every fresh viewB open — never an ambiguous "nothing selected" state) · **Installed** · **Recent** · **Favorites** (§2 — always a subset of Installed, per §3.2's installed-only favoriting rule)
2. **Category group** (below): the real categories (Clipboard, Meeting, Appearance, …), each with its accordion-nested subcategories exactly as in the current mockups

**Group divider — LOCKED: dot-leader label, above both groups.** Small uppercase group label ("Browse" / "Categories") with a trailing dotted line filling the rest of the row width, table-of-contents style — applied above **both** groups equally, not just before Categories (an earlier pass only labeled the second group, which read as lopsided once compared against 7 other options in the visual companion: hairline+label, hairline-only, label-only, spacing-only, a tinted background panel around the scope group, an icon+trailing-line header, and a tab-switcher replacing the rail rows entirely). Dot-leader chosen over plain hairline+label for a slightly more distinct, less generic-nav-chrome feel.

**Consequence: scope and category are mutually exclusive by construction** — selecting "Favorites" is the same action as selecting "Meeting," just a different row in the same list. Only one row is ever active. This resolves the earlier "combinable vs. exclusive" open question without needing a design for combining two axes — there's only one axis (row selection), scope rows and category rows just live in the same list.

The "…" icon from viewA (§2) opens viewB with the **Favorites** row pre-selected instead of the default **All** row.

**Recent scope — retention rules LOCKED.** An addon becomes "Recent" on **any interaction** with it — opening its detail view, running any of its commands, or installing it — the broadest "I touched this" signal, matching Spotlight/Raycast-style Recent behavior rather than narrowing to just command-runs or just install events. List is a **fixed-cap MRU (most-recently-used), capped at 10**, most recent first, no time-based decay — new activity naturally bumps old entries off the end, so a separate expiry rule would be redundant complexity. Cap of 10 sized for viewB's 3-per-row grid (fills to just over 3 full rows).

### 3.2 Addon card — content LOCKED, visual style not started

**Card content — full list, LOCKED:**

1. Icon
2. Name
3. One-line description
4. Favorite star/pin — **installed-only** (see below)
5. Official/first-party badge — small mark near icon or name; its *absence* implies third-party once third-party addons exist (repo is 100% first-party today, designed ahead of that need)
6. Install-area, **3-state**: **Not Installed** → `[Install]` button · **Installed + Enabled** → toggle (on) · **Installed + Disabled** → toggle (off). **Card-level visual dimming groups by "is this active right now," not "is this installed"** — see §3.2's card-state section below, which supersedes this row's original enabled/disabled-distinct reasoning.

**Explicitly excluded from the card (detail-view-only):**

- Category/subcategory label — redundant when browsing within a category; only useful in mixed scopes (Favorites/Recent), not worth the card space
- Command count (addons can have multiple commands per [vision.md](../vision.md#catalog-hierarchy-user-pov--locked-intent)) — detail view only
- Size/version — detail view only
- Tag badges (popular/new/free) — tags (§3, list region) stay a pure filter control up top; no echo on the card itself, keeps the card visually calm

**Interaction, LOCKED:**

- **Favoriting is installed-only.** Star/pin toggle only appears (and only works) on cards for already-installed addons. Favoriting an uninstalled addon is not supported — no "favorite to auto-install" or "mark intent" behavior. Consequence: the Favorites scope (§3.1) is always a subset of the Installed scope, which simplifies how those two scopes relate.
- **The card's "Details" link opens a detail view:** screenshots, full description, permissions, commands list, category/subcategory, command count, size/version. The install button/toggle on the card itself remains a fast-path shortcut that skips the detail view entirely.
- **Detail view stacks on top of viewB.** Matches the shell's existing panel-stack model ([shell surface presets](./2026-08-23-shell-surface-presets.md)) — viewB stays open behind it (dimmed/inactive), closing the detail view returns to viewB exactly where the user left off (scope/category/scroll state preserved, not re-navigated).

### 3.3 Detail view — structure LOCKED

**Not `rail`.** Since the detail view stacks on top of viewB rather than replacing it, it inherits roughly viewB's own **landscape** proportions — but **smaller than viewB on both axes, not identical footprint** (~700×475pt in mockups vs. viewB's ~864×585pt) — a narrow portrait `rail` (the earlier candidate, capped ~520–560pt wide per [view types §3](./2026-08-24-view-types.md)) was the wrong shape once actually mocked up. **viewB's card grid/rail visibly fades/dims behind the detail view** (not just logically inactive) — same visual language as any stacked panel in this doc, made explicit here. Exact view-type reconciliation and precise size delta still open (§5).

**Structure — LOCKED: gallery + tabs (option B of 3 explored).** Explored two other shapes: a two-column layout (identity/screenshots fixed left, info scrolls right — rejected, screenshots deserved more width than a fixed sidebar gives them) and a 3-column dashboard (description/commands/permissions side by side, no scroll — rejected in favor of B, though revisit if B's tabs feel like one click too many for a compact info set). Locked layout, top to bottom:

1. **Header** — icon + name + category/subcategory breadcrumb, close (✕) control
2. **Screenshot gallery** — landscape strip directly below the header, **horizontally scrollable** (not a fixed 2-3 grid — holds however many screenshots an addon has, user scrolls/swipes through)
3. **Tab strip** spanning the full width — **labels LOCKED: Overview / Commands / Permissions**, plain text tabs with underline indicator (per the mockup). Confirmed after comparing against 5 other structural directions (icon+text pills, icon-only tabs, no-tabs single-scroll page with sticky headers, a sidebar mini-nav echoing viewB's own rail, numbered step chips) — plain text tabs stay clearest, and "Permissions" in particular should stay literal rather than softened, since it's a trust/security-relevant label. Size/version folds into the Overview tab, not a separate tab.
4. **Tab body** — scrolls independently below the tabs if its content overflows

Content per tab, from the original locked list (§3.2's card decisions): Overview = full description + size/version + **command count** (LOCKED as an explicit metadata row alongside Version/Size — same pattern, cheap to add, and knowing "1 command" vs. "5 commands" is meaningful before switching to the Commands tab to decide whether to install); Commands = the addon's command list with keyboard shortcuts; Permissions = required-permissions list (ties to [ticket 0038](../tickets.md)'s pre-install permissions disclosure — this view is a natural second place that same data surfaces, not a duplicate design).

**Open transition — LOCKED: genie effect, from the clicked card's position.** Clicking a card's "Details" link doesn't fade or pop the detail view in generically — it **unfurls from that exact card's screen position and size** toward the detail view's real size/position (centered over the dimmed viewB behind it), echoing macOS Dock's Genie minimize/restore effect rather than a plain scale-fade. Reverses symmetrically on close (✕, Esc, or click-outside-detail per §3.3's stack rules) — the panel funnels back down into the same card it came from, not a generic fade-out.

Two implementation details worth carrying forward, found while prototyping in the visual companion:
- **The funnel/taper is a shape change (clip-path), separate from the position/size change (transform: translate+scale)** — animating both from a single unified keyframe timeline (not two independently-timed animations) avoids visible desync/stutter between the two effects.
- **The starting/ending clip-path shape must be a real, non-degenerate polygon** (a proper taper toward one edge), not a near-zero-size point-like shape — interpolating from a degenerate shape reads as a discontinuous jump/blip rather than smooth continuous motion, since the browser has no meaningful path to tween through.

**Card visual style — LOCKED: single face, no flip.**

- Card: icon, official badge (top-right), favorite star (top-right, installed-only, ember when favorited), name, description, state control (toggle Enabled/Disabled for installed, or `Install` pill for not-yet-installed), and a **footer row** below the state control, separated by a thin top border: **"Details"** (left, plain `textSecondary` link) and **"Uninstall"** (right, `error`-colored link, omitted for not-yet-installed addons). **"Details" always stays left, never re-centers or shifts when Uninstall is absent** — its position must stay predictable and fixed regardless of state, not shuffle around as a card's other content changes. Card sized ~210×185pt to fit the footer row; grid stays 3-per-row at viewB's width.
- Footer treatment (text links) chosen over two alternatives explored in the visual companion: an icon-button footer (ⓘ / 🗑, no labels — rejected, icons alone read less clearly than words for a destructive action) and a kebab (⋯) popup menu reproducing a fuller action list — rejected, a click-to-reveal popup adds indirection for what should be a direct action, and risks overlapping neighboring cards.
- Disable/Enable and Favorite are not footer actions — they're the front-face toggle and star. The footer only holds the two actions with no other home: Details and Uninstall.
- Uninstall opens the existing confirm (`ask`) dialog before anything happens.
- Details opens the detail view directly, no intermediate animation.

**Card states — LOCKED: Active vs. Inactive grouping, not Installed vs. Not-installed.**

Reopened from an earlier open item ("addon card states beyond install/uninstall/favorite: hover, disabled/enabled toggle"). Considered three groupings for how the card visually distinguishes states: (a) two groups, Enabled vs. {Disabled + Not-installed}; (b) two groups, Installed vs. Not-installed; (c) three distinct groups, Enabled / Disabled / Not-installed. **Chosen: (a).** Reasoning: a disabled-but-installed addon and a not-installed addon are functionally identical from "would this currently do anything for me" — the question a user is actually asking when scanning a grid — so they share one visual treatment ("Inactive"). This drops the earlier lock that disabled must look visually distinct from not-installed; the toggle itself still shows the real Enabled/Disabled state precisely, the card-level treatment just doesn't duplicate that distinction. (b) was rejected — it answers "is this on my machine," a different and less useful question at grid-scan glance, and would hide whether an installed addon is actually doing anything without close inspection of the tiny toggle. (c) was rejected as unnecessary complexity — three visual treatments to design and keep distinguishable, when (a) already captures the question that matters most for a fast scan.

**Card-wide hover — LOCKED: zoom (scale up in place) + shadow, combined with an accent glow border.** On hover, the card scales up slightly in place (not a vertical lift/translateY — corrected after mocking both; zoom reads better than float for a grid of same-size cards) with a growing shadow, and its border simultaneously glows accent-colored — both effects together, not either alone. Chosen as a card-wide affordance even though no single click action covers the whole card anymore (post no-flip redesign, only the star/toggle/Details/Uninstall have individual actions) — a card-wide hover still reads as "you're in this card's territory" without implying the whole card is one clickable unit, since the individual controls carry their own distinct hover feedback on top of it.

**Inactive-card action button — LOCKED: glow pulse, triggered by hovering the card (not the button).** For Inactive cards that have a real action button (`Install` for not-installed, or the Enable/Disable toggle read as "act on me" for disabled), hovering **anywhere on the card** — same trigger zone as the card-wide zoom+glow above — also makes that action button pulse with a soft breathing glow ring. Explored and rejected: shake/wiggle (felt gimmicky once seen on the real card, not just an isolated button), solid-fill "wake up" color change (functional but less noticeable at a glance than a glow pulse), pulse/scale bounce, an arrow sliding in, and an underline sweep. Active/Enabled cards have no such button, so hovering them triggers only the card-wide zoom+glow with no additional button effect.

**Inactive treatment — LOCKED: dim (opacity) + status dot, combined.** Explored 6+ structurally distinct mechanisms in the visual companion beyond simple opacity tweaks: status dot on the icon corner, outline/ghost icon (loses fill), sunken/inset card shadow vs. raised, sort-order-only (inactive addons sort to the grid's bottom, no visual change), a plain text state label replacing the toggle graphic, the app's own firefly glow motif (icon glow halo present/absent, reusing favorites' lit/dim language from §2), plus opacity fade, desaturated icon, surface2-flatten, dashed border, and a diagonal corner ribbon. **Chosen: dim (card at reduced opacity) + a small status dot on the icon's corner, together** — dim gives the fast, unmissable "this one's different" signal at grid-scan distance; the dot adds a precise, always-in-the-same-spot detail for closer inspection. Ribbon was rejected — its literal "INACTIVE" text reads as promotional/badge-y (sale tag, "NEW" sticker connotation), tonally mismatched with the card's already-locked "no tag badges, keep it visually calm" rule (§3.2's card-content list). Sort-order-only was rejected as the sole signal — too easy to miss without a visual cue, though nothing here precludes also sorting Inactive cards toward the grid's end as a secondary behavior (not decided either way, not blocking).

**List region (right of rail):**
- **Tag chips — interaction LOCKED.** Horizontal row at the top (e.g. "popular", "new", "free"). **Multi-select, OR logic** — clicking multiple tags shows anything matching *any* selected tag (standard filter-chip behavior). **Combines with (AND) whatever rail row is active** — the rail selection (§3.1: a scope row like Installed, or a category/subcategory row like Meeting) is not reset or overridden by tag selection; tags narrow *within* it. E.g. viewing "Meeting" in the rail + selecting the "new" tag shows new Meeting addons only, not new addons catalog-wide.
- **Tag chip visual style — LOCKED: glow/lit.** Selected tags get a tinted ember background + soft ember glow (same "lit" visual language already locked for favorites-icon state, §2 — a deliberate reuse, not a coincidence). Unselected tags stay a plain outline chip. Explored and rejected: filled pill (flat ember fill, no glow), checkbox-style (small check icon inside the chip), underline-only (no background change at all, too minimal against the rest of the theme's visual weight), ring+dot (thin border ring + small leading dot).
- Grid of addon cards below, 3 per row at the locked panel width — each card: icon, name, one-line description, install/uninstall button. Card visual spec (corner radius, border, hover state) reuses the same `JugnuTokens`/`JugnuTheme` system as the rest of the shell — no new token category introduced for cards themselves.

## 4. Theming — new tokens surfaced by this design

The [product pass spec](./2026-08-23-palette-ui-product-pass.md#3-shared-design-tokens--swiftui-migration-for-appkit-panels) locks 6 core `JugnuTheme` fields: `accent`, `background`, `surface`, `textPrimary`, `textSecondary`, `error`. Building viewB's rail surfaced a real gap: `textSecondary` alone doesn't give enough contrast steps for a nav region with an inactive/active state plus a "readable but secondary" label tier.

**New token needed:** `subText` — a brightness step between `textSecondary` and `textPrimary`, used for subcategory row labels (and potentially other "secondary but must stay legible" nav text elsewhere). Not yet added to the real `JugnuTheme` Swift struct or the shipped 3-preset tables in code — still only a mockup-level constant — but working values are chosen and verified for all 3 presets × 2 modes in the [living mockup](./2026-08-25-launcher-catalog-mockup.html)'s theme switcher:

| Preset | Dark `subText` | Light `subText` |
|---|---|---|
| Firefly | `#B8AF9E` | `#5B5647` |
| Terminal Phosphor | `#6FAF7C` | `#385E43` |
| Rose Quartz | `#D2A9BF` | `#6F4A5E` |

Also surfaced: a `border` value distinct from `surface`, and a `surface2` (used for the official badge's slightly-lifted background and the accordion rail's group background) distinct from `surface` itself, plus `accentDeep` (the icon gradient's darker stop).

**Token status — LOCKED:**

- **`subText` becomes a real `JugnuTheme` Swift struct field**, with hand-picked hex values per preset × mode (the 6 values already verified in the mockup's `THEMES` object, per the table above). It's used for content people must read at a glance (subcategory nav labels), and its per-preset values aren't one consistent formula off an existing token — e.g. Firefly dark `#B8AF9E` vs. Terminal dark `#6FAF7C` is a hue shift, not just a brightness step — so a derived/computed value risks producing bad contrast on a future preset nobody explicitly checked.
- **`border`, `surface2`, `accentDeep` stay derived** — computed from existing `JugnuTheme` fields (e.g. `surface` at a fixed opacity/darken step) rather than added as new struct fields. They're subtler/more mechanical (hairlines, slightly-lifted backgrounds, gradient stops) — lower risk if the computed value drifts slightly, and no new per-preset table to hand-maintain as more presets are added later.

**Verified against all 3 locked presets (Firefly, Terminal Phosphor, Rose Quartz) × light/dark = 6 combinations** — the [living mockup](./2026-08-25-launcher-catalog-mockup.html) has a live theme switcher (top-right, mode + preset dropdowns) covering all 6, not just static screenshots. Terminal Phosphor auto-switches to monospace type per the existing note in the product-pass spec (§3) that it pairs naturally with SF Mono.

## 5. Open questions (not yet decided)

- **Unified icon system (addon icons + UI chrome) — parked as [ticket 0051](../tickets.md), scope expanded 2026-08-26.** Every icon in the app — per-addon icons **and** UI chrome icons (close, search, star, badges, and other small functional glyphs, currently emoji/text placeholders like ✕ and 🔍 throughout viewA/viewB/detail view) — should be hand-drawn, share the app icon's glow-motif visual language, and re-tint (primary/secondary) per active theme, not be arbitrary/mixed-source art (emoji, system symbols, fixed per-addon art). Real design work (construction rules, template format, full glyph inventory, per-icon supply mechanism) deferred to when that ticket is picked up — a single unified decision, not two separate icon efforts. **Until then, use placeholders everywhere an icon appears**: default app icon for addon icons (favorites row, catalog cards), plain emoji/text glyphs for UI chrome (✕, 🔍, ★, etc.) — this doc's mockups use both kinds of stand-ins, not final art.
- Preferences surface (from viewA's prefs button): confirmed likely `rail` per existing pattern-default mapping, not yet designed in depth
- Possible future icon-only "minimize" affordance for the categories rail (raised when rejecting option F as the *only* mode) — not designed, just flagged as worth keeping in mind

## Related

- [Vision — Surfaces](../vision.md)
- [Shell design](./2026-08-22-shell-design.md)
- [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md)
- [View types](./2026-08-24-view-types.md)
- [Shell surface presets](./2026-08-23-shell-surface-presets.md)
- [Ticket 0002](../tickets.md) — addon management / Preferences redesign + catalog browse
- Architecture index: [README](./README.md)
