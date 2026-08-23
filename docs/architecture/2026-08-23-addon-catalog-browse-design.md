# Jugnu — addon catalog browse + category/tag taxonomy

**Date:** 2026-08-23
**Status:** Draft — under active discussion, not yet approved
**Scope:** Registry schema (`category`, `subcategory`, `tags`, `description`, `commands`), a new dedicated `BrowseCatalogWindow` (separate from `PrefsView`'s "My Addons"), addon detail view, install-from-browse flow, a shell-native "Browse Addons" palette command, uninstall-confirmation for **both** Browse Catalog and My Addons (found during this design: My Addons' existing Uninstall was instant/unconfirmed — fixed here since Browse duplicates the same destructive action onto a second surface)
**Depends on:** [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) — `JugnuUI` tokens/theme, `PrefsView` sectioned layout, `UserFacingError`, `AddonInstaller`/`AddonLifecycle` all already land there
**Out of scope here:** Screenshots in the detail view (real cost — asset hosting/maintenance per addon, payoff mainly for popup-UI addons — deferred as its own future design); a future palette/menu-bar "front view" button row (Preferences would be the first button added there, per product intent) — noted so it isn't lost, not designed or built this epic; security hardening of the install path itself ([ticket 0003](../tickets.md)); persistent latency logging ([ticket 0001](../tickets.md)); **`FirstRunWindow` redesign** (full catalog view with `recommended`-tagged addons pre-selected, Skip/Next flow, redirect into Browse Catalog after — real scope discussed and deliberately split out as its own follow-on ticket, since it reworks a different existing flow beyond this epic's registry/browse-window surface; the `recommended` tag (§2, §3) is added here specifically so that ticket has what it needs without a second data pass)

## 1. Why now

[Ticket 0002](../tickets.md) was split out of the palette/UI product pass epic specifically because its dependency — `JugnuUI` tokens, theming, and a sectioned `PrefsView` — needed to land first. It has (`swift test` green, 39 tests, theme section shipped in `PrefsView`). `registry/addons.json` already carries a stub note under "Later" for a `category` field ([registry/README.md](../../registry/README.md)); this epic makes good on it. Today `PrefsView`'s "Addons" section only ever shows the addons a user already installed — there is no way to discover the other addons in the registry without reading `registry/addons.json` by hand.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Taxonomy model | **Three levels available, two populated today.** `category` — single required value per addon, structural grouping, matches [vision.md's Catalog hierarchy](../vision.md) ("Category — Taxonomy only"). `subcategory` — single **optional** value per addon, nested under a category, for when a category grows enough members to need its own internal split. `tags` — multiple values per addon, cross-cutting facets for filtering across (not instead of) category/subcategory. Vision.md's Category language is unchanged; subcategory and tags are additive. Built for real planned scale (many more addons ahead), not just today's 11 — the model exists now so growth doesn't force a schema migration later, but subcategory is populated only where a category has actually earned the split (§3) |
| Category list (locked) | `Clipboard`, `Focus`, `System`, `Info`, `Notes` — named for the job-area a user thinks in, matching vision.md's own example names (Clipboard, Meeting, Appearance, Converters, Play) |
| Subcategory (locked, populated now) | `System` splits into `Dev Tools` (brew-outdated, ports) and `Monitoring` (battery-eta) — the one category with enough distinct member intents today to earn it. `Clipboard`, `Focus`, `Info`, `Notes` stay flat (no subcategory) until they grow enough to need one |
| Sidebar rendering rule | A category renders as a flat row if it has zero or one distinct subcategory value among its members; renders as an expandable row (category → its subcategories) only once ≥2 distinct subcategory values exist under it. No empty/speculative subcategory nodes ever shown |
| Tag vocabulary (locked) | `quick-glance` (read-only status / one-shot toast), `toggle` (on/off switch), `background` (runs a watcher/timer/launchd agent), `popup-ui` (opens a list/note/form panel), `dev-tool` (developer-focused), `recommended` (part of the curated first-run set — assigned now since tags are being written anyway, consumed by [the follow-on first-run ticket](../tickets.md), not read by anything in this epic itself) |
| Category + tag assignment (locked, all 11 addons) | See §3 table |
| Browse window | **Own separate resizable window, not a `PrefsView` section.** `PrefsView` stays its current compact shape (My Addons list + Theme) — a sidebar+card-grid+tag-chips+detail-view layout genuinely needs App Store–scale room a small settings pane isn't built for. New `BrowseCatalogWindow` (own `NSWindow`/`NSHostingController`, resizable, sized like a real content browser). Opened from: a button in `PrefsView` ("Browse Catalog…"), and the shell-native "Browse Addons" palette command (§C) — both just open/focus this window, not a Preferences tab |
| Browse vs. My Addons split | Two separate surfaces, not tabs in one window. My Addons stays in `PrefsView` (installed, manage — enable/disable/uninstall unchanged). Browse Catalog is the new dedicated window (full registry, filter, install) |
| Filter interaction | Category sidebar/tabs (`All` + the 5 categories) as primary grouping; tag chips as a secondary multi-select filter; a text search box as a third, orthogonal filter — all three compose (search narrows whatever category+tag selection is active). Search reuses `Fuzzy.score` (`shell/Sources/JugnuCore/Fuzzy.swift`, already proven in palette search) over each entry's `name`/`summary`/`tags`, not a new matching algorithm. Real scale (many more addons planned, not just today's 11) is the explicit reason search is core here, not deferred — category+tags alone don't help a user who knows roughly what they want by name |
| Card content | Name, one-line `summary` (existing field), category label, tag chips, action buttons — see "Card action surface" row below for the full Install/Uninstall/Enable/Disable behavior |
| Detail view | Card is expandable to a detail view: long-form `description` (**new** registry field, distinct from the existing short `summary`), full command list (title/subtitle per command — read from the registry's generated `commands` field, §A2), version, **and the same action row as the card** (Install / Uninstall+Enable-Disable, same color language, same `ConfirmPanel` uninstall-confirm) — a user reading the full description shouldn't have to close the detail view and hunt for the card to act. Some addons (list/form/note-pattern ones) are complex enough to warrant a detail view — not every addon is a one-line toggle |
| Screenshots | **Deferred.** Real cost (asset hosting — registry is static JSON pointing at GitHub Release assets, so screenshots need their own asset pipeline; per-addon maintenance as UI changes) with payoff concentrated in popup-UI addons only, not toggle/status ones. Own future design, not this epic |
| Install flow | **Reuses `AddonInstaller`/`AddonLifecycle` unchanged** — same download → sha256-verify → unpack-to-temp → verify → copy-into-`addonsDir` → enable path `FirstRunWindow` already exercises. Browse Catalog's Install button triggers the same call, not a new mechanism. Card shows an installing state, flips to "Installed" + the addon appears in My Addons on success |
| Partial install / crash mid-download (checked, not assumed) | **Already safe, no new work.** `AddonInstaller.installFromLocalZip` (`shell/Sources/JugnuCore/AddonInstaller.swift`) unpacks to a temp `extractRoot` and validates (sha256, `addon.yaml` presence, id match) entirely before ever touching the real `paths.addonsDir` — a crash mid-download or mid-unpack leaves no partial state in the real addons directory, nothing to clean up on next launch. One narrow pre-existing gap noted, not solved here: the final `copyItem` into `dest` (line 59) is not itself atomic against a crash *during* that copy — same class of concern as [ticket 0003](../tickets.md)'s install-path hardening scope, not new risk this epic introduces |
| Install error surface | **Inline banner on the card/detail view**, not toast, not `PanelErrorBanner`. Uses `UserFacingError.message(for:)` for copy — same error-mapping/tone as the rest of the app — but a new lightweight placement suited to a titled-window context (`PanelErrorBanner` was built for the borderless floating panels, a different chrome) |
| Card action surface (revised — bigger than discovery-only) | **Browse Catalog cards carry full management, not just Install.** Not-installed: `Install` button. Installed: `Uninstall` button **and** an `Enable`/`Disable` toggle — duplicating My Addons' management actions inside Browse, not just a read-only "Installed" badge. This means the same enable/disable/uninstall state now has two live surfaces (My Addons list, Browse Catalog card) that must stay in sync — both read/write through the same `AddonLifecycle`/`ConfigStore` calls My Addons already uses, no separate state |
| Button color language | Affirmative/on actions (`Install`, `Enable`) use `theme.accent`; destructive/off actions (`Uninstall`, `Disable`) use `theme.error` — reuses the two color tokens `JugnuTheme` already defines, no new palette entry needed |
| Uninstall confirmation (checked, real gap — fixed in both surfaces) | **`PrefsView`'s existing My Addons "Uninstall" button fires instantly today, no confirmation** (`shell/App/PrefsView.swift` — calls `model.uninstall(id:)` directly from the button action). With Browse Catalog adding a second Uninstall button for the same destructive action (real data loss risk — `clipboard-history`'s uninstall tears down a running launchd watcher and deletes local history), this epic adds a confirm step to **both** surfaces, not just the new one. Reuses the existing `ConfirmPanel` (`shell/Sources/JugnuUI/ConfirmPanel.swift`, SwiftUI/tokens/theme, already built and hosted in an `NSPanel` from any window context) rather than a new bespoke dialog or native `NSAlert` — one confirm pattern app-wide |
| Registry schema growth | `category: String` (**required**), `subcategory: String?` (**optional, absent/null for most addons today**), `tags: [String]` (**optional, defaults `[]`**), `description: String`, `commands: [{id, title, subtitle}]` added to each `registry/addons.json` entry, alongside existing `id`/`name`/`version`/`api`/`url`/`sha256`/`summary`. Additive only — no existing field changes shape |
| Missing category | **Hard decode failure**, not a UI fallback bucket — `category` is mandatory on every registry entry, same strictness as `id`/`name`/`sha256` today. A malformed entry is a data bug to catch at decode time, not a "Uncategorized" sidebar item to design around |
| Missing/empty tags | Renders as a single synthetic `untagged` chip on the card — same chip styling as real tags, so a tag-less addon doesn't look broken or half-designed. `untagged` is a display-only synthetic value, not written into `registry/addons.json` and not one of the 5 real tag-vocabulary values |
| Command list source | **Generated, not hand-written.** `commands` is derived from each addon's own `addon.yaml` (already the source of truth for what an addon exposes) by a new sync script, not duplicated by hand and not fetched live from inside the zip at browse time. `category`/`tags`/`description`/`summary` stay hand-authored product copy — the script never touches them |
| Registry caching (checked, real gap) | **`RegistryClient.fetch` has zero caching today** (`shell/Sources/JugnuCore/RegistryClient.swift`) — every call is a live network round-trip with no local persistence, no offline fallback; `FirstRunWindow` doesn't even use it (it installs from local dev-path fallback, a separate mechanism). Opening `BrowseCatalogWindow` on every launch would otherwise mean network-or-broken with no middle ground. **New: `JugnuPaths.registryCacheFile`** (`~/.local/share/jugnu/state/registry-cache.json`, alongside the existing addon state dirs). `BrowseCatalogWindow` open: fetch live; on success, write result to cache and display; on failure, fall back to the cached copy (if any) with a small inline "Showing cached results — offline or registry unreachable" banner; if no cache exists and fetch fails, show the plain error state (via `UserFacingError`) |

## 3. Category + subcategory + tag assignment (all 11 addons)

| Addon | Category | Subcategory | Tags |
|---|---|---|---|
| `battery-eta` | System | Monitoring | `quick-glance` |
| `brew-outdated` | System | Dev Tools | `quick-glance`, `popup-ui`, `dev-tool` |
| `clipboard-history` | Clipboard | — | `background`, `popup-ui` |
| `floating-note` | Notes | — | `popup-ui`, `recommended` |
| `focus-toggle` | Focus | — | `toggle`, `recommended` |
| `mic-mute` | Focus | — | `toggle`, `recommended` |
| `paste-plain` | Clipboard | — | `quick-glance`, `recommended` |
| `pomodoro` | Focus | — | `background`, `toggle` |
| `ports` | System | Dev Tools | `popup-ui`, `dev-tool`, `recommended` |
| `weather-bar` | Info | — | `quick-glance` |
| `world-clock` | Info | — | `quick-glance`, `popup-ui` |

`recommended` marks the 5 addons `ShellConfig.recommendedAddonIDs` (`shell/Sources/JugnuCore/Models.swift`) already names as the first-run curated set (locked in the [palette/UI product pass](./2026-08-23-palette-ui-product-pass.md)'s Task 6) — assigned here so the follow-on first-run ticket doesn't need a second data pass.

`background` reflects a real launchd/watcher/timer side effect (checked against each `addon.yaml`'s `cleanup.launchd`/`cleanup.paths` and known runtime behavior — `clipboard-history`'s watcher, `pomodoro`'s running timer state), not just "runs in the background conceptually."

`System` is the only category with ≥2 distinct subcategory values today (Dev Tools, Monitoring), so it's the only one that renders expandable in the sidebar (§2 rendering rule). The other 4 categories have every member at subcategory `—` (none), so they stay flat rows — adding a second real category-outgrowing-flat moment (e.g. `Focus` splitting into "Timers" vs. "Toggles" once it has enough members) is a data-only change under this same model, no new UI work.

## 4. Depth by front

### A0. Registry client caching

- `JugnuPaths` gains `registryCacheFile: URL` → `home/.local/share/jugnu/state/registry-cache.json`.
- `RegistryClient` gains a `fetchWithCache(from:cacheFile:) async -> RegistryFetchResult` (or similar): tries `fetch(from:)`; on success, writes the raw response to `cacheFile` and returns `.fresh([RegistryEntry])`; on failure, reads `cacheFile` if present and returns `.cached([RegistryEntry])`; if both fail, returns `.unavailable(Error)`.
- `BrowseCatalogWindow`'s view model calls this on open (and on an explicit manual refresh, if one is added later — not required for v1). `.cached` renders the catalog normally plus the "Showing cached results" banner; `.unavailable` renders the existing error-state pattern via `UserFacingError`.
- Cache write is best-effort (`try?`) — a failed cache write never blocks showing fresh results, matches this codebase's existing "never crash on local persistence noise" posture (e.g. `JugnuTheme.sanitized` never crashing on bad hex).

### A. Registry schema

- `registry/addons.json`: add `category` (one of the 5 locked names), `subcategory` (optional, only `System` entries set it today), `tags` (array, from the 6-value vocabulary including `recommended`), and `description` (long-form, 2-4 sentences, written per addon) to all 11 entries per §3 — all hand-authored. `commands` is separately populated by the sync script (§A2), not hand-written here.
- `registry/README.md`: update to document the new fields, replacing its current "Later: a `category`..." stub note.
- No `AddonInstaller`/download/sha256 logic changes — these are read-only display fields, not install-path fields.
- `RegistryClient` (`shell/Sources/JugnuCore/RegistryClient.swift`) and its decode model gain `category` (required — missing/invalid value fails decode of that entry, same strictness as existing required fields), `subcategory` (optional, `nil` default), `tags` (optional, defaults `[]`), `description` (optional, `nil` falls back to `summary` in the detail view), `commands` (optional, defaults `[]`).

### A2. Registry `commands` sync script

- New `scripts/sync-registry-commands.py` (matches the existing Python tooling in `scripts/`, `pyproject.toml`/`uv` already set up): reads every `addons/<id>/addon.yaml`, extracts each command's `id`/`title`/`subtitle`, writes/updates the `commands` array on the matching `registry/addons.json` entry. Only touches `commands` — never writes `category`/`tags`/`description`/`summary`/`version`/`url`/`sha256`.
- `--check` mode (**used only in CI**): run the same generation in memory, diff against the committed `registry/addons.json`, exit non-zero if they differ, writes nothing — same shape as `ruff check`/`mypy` in `make ci`.
- **Pre-commit hook behavior (deliberately different from `--check`):** the local pre-commit hook runs the script **without** `--check` — it regenerates `registry/addons.json` on disk if stale and exits non-zero to block the commit, but **does not re-stage the file**, unlike this repo's `ruff-check --fix` hook. The contributor sees the modified file in their working tree, reviews the diff themselves, and stages it deliberately — no silently-auto-staged content ever enters a commit through this hook.
- Wired into `.pre-commit-config.yaml` (local, auto-fix-no-restage per above) and `.github/workflows/ci.yml` (authoritative gate, `--check` mode, matches existing `ruff`/`mypy`/`codespell`/`pytest`/`semgrep` jobs).

### A3. Uninstall confirmation (My Addons + Browse Catalog)

- `PrefsView`'s existing Uninstall button (My Addons section) changes from calling `model.uninstall(id:)` directly to first presenting `ConfirmPanel` ("Uninstall {name}? This removes it and any local data it stored." — copy per this epic's warm-but-restrained tone standard) with Cancel/Confirm; only Confirm calls `model.uninstall(id:)`.
- Browse Catalog's Uninstall button (§B) uses the identical `ConfirmPanel` flow, same copy template, same confirm-triggers-`AddonLifecycle`-uninstall call as My Addons.
- One shared confirmation helper (e.g. a small `AddonUninstallConfirmation` view-model or free function taking `id`/`name` and an `onConfirm` closure), called from both `PrefsView` and `BrowseCatalogWindow` — not two independent copies of the same wiring.

### B. Browse Catalog UI (new `BrowseCatalogWindow`)

- New dedicated `NSWindow`/`NSHostingController`, resizable, separate from `PrefsView`. `PrefsView` gains one new button ("Browse Catalog…") that opens/focuses this window; `PrefsView`'s own layout (My Addons, Theme) is otherwise unchanged by this epic.
- Category sidebar/tabs: `All`, `Clipboard`, `Focus`, `System`, `Info`, `Notes`. `System` renders expandable (Dev Tools / Monitoring) per §2's rendering rule; the other 4 stay flat rows today.
- Tag chip row: multi-select, filters within the current category selection (or across `All`).
- Search box: text field, debounced same as palette's (~100ms), fuzzy-matches `Fuzzy.score` over `name`/`summary`/`tags` per entry, composes with the active category + tag filters (all three narrow the same result set together, not independently).
- Card grid: name, summary, category label, tag chips (or a single synthetic `untagged` chip when `tags` is empty). Action area: not-installed → `Install` button (`theme.accent`); installed → `Uninstall` button (`theme.error`) plus an `Enable`/`Disable` toggle (accent when enabled, error when disabled). While installing: button disabled, label "Installing…" with a spinner, matching `SkeletonPanel`'s existing loading-state visual language.
- Enable/disable/uninstall from a Browse card call the exact same `AddonLifecycle`/`ConfigStore` functions `PrefsView`'s My Addons section already calls — one source of truth for addon state, both windows just observe/mutate it. `AppModel`'s existing `@Published config` (already reactive per the palette/UI epic's Theming work) keeps both windows in sync live if both happen to be open at once.
- Click/tap a card (not an action button) opens the detail view: description, full command list (from the registry's generated `commands` field, §A2 — available pre-install, no partial-zip fetch needed), version, and the same action row as the card (Install / Uninstall+Enable-Disable) — acting from detail view updates the underlying state exactly like acting from the card (same shared calls, §92), and the card behind it reflects the change when the detail view closes.
- Uses `JugnuTokens`/`JugnuTheme` throughout — same visual system as the rest of the app, no new ad hoc styling.

### C. Palette entry point

- New built-in shell command (not an addon): "Browse Addons" — opens/focuses `BrowseCatalogWindow` directly (creating it if not already open). Lives alongside any other shell-native palette entries (distinct from addon-supplied commands in `CommandIndex`).

### D. Install-from-browse

- Card's Install button calls the existing `AddonInstaller.install`/`AddonLifecycle` path.
- In-progress state: disabled button, "Installing…" label + spinner (§B).
- On success: card flips to "Installed", addon appears in My Addons section (enabled by default, matching first-run behavior).
- On failure: inline error banner on the card (or detail view, if open) via `UserFacingError.message(for:)`. Does not toast, does not use `PanelErrorBanner`.

## 5. Open questions

None outstanding — all resolved in §2–4 above.

## 6. Success criteria

1. `registry/addons.json` carries `category`, `tags`, `description`, `commands` for all 11 addons; `RegistryClient` decodes them without breaking existing install/update flows.
2. A dedicated Browse Catalog window opens (from Preferences or the palette), distinct from `PrefsView`'s "My Addons"; category sidebar + tag chips + text search all filter the card grid correctly, composing together.
3. Registry fetch failure with an existing cache shows cached results + a visible staleness banner, not a blank/broken window; failure with no cache shows a plain error state.
4. Clicking a card opens a detail view with description, command list, version.
5. `scripts/sync-registry-commands.py --check` fails CI when an `addon.yaml` command changes without a matching `registry/addons.json` update; passes when in sync.
6. Installing from a Browse Catalog card uses the same `AddonInstaller` path as first-run install; success moves the addon into My Addons; failure shows an inline banner with `UserFacingError` copy, not a toast.
7. A palette command opens/focuses the dedicated Browse Catalog window directly.
8. No existing "My Addons" behavior (enable/disable) regresses; Uninstall in both My Addons and Browse Catalog requires confirming via `ConfirmPanel` before it fires — no instant/unconfirmed uninstall remains anywhere.

## Related

- [Vision — Catalog hierarchy](../vision.md)
- [Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md)
- [Registry README](../../registry/README.md)
- [Tickets](../tickets.md) — ticket 0002 (this spec); ticket 0004 split out of this discussion (first-run redesign, depends on this epic)
- Architecture index: [README](./README.md)
