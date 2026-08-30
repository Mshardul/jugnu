# Catalog-hygiene audit

## How to run

Fresh agent session. Read this whole file. Work the checklist as todos. Write the
report to `docs/audit/report/pending/YYYY-MM-DD-catalog-hygiene.md` from
`docs/audit/report/_template.md`. **First check `report/pending/` — if a
`*-catalog-hygiene.md` already sits there, stop and tell the user.** After
writing the report, update this prompt's row in [`README.md`](README.md) —
Last run = today, Last severity = the worst finding.

## POV

The addon catalog as a user sees it. `AGENTS.md` → **Addon packaging (user POV)**
locks a set of packaging rules: name the job not the scenario, merge paired
toggles, club similar converters onto one addon, helpers vs addons, bundles are
not a catalog level, etc. This audit checks the shipped catalog against those
rules and against the `backlog.md` packaging map.

## Scope — in

- `AGENTS.md` → "Addon packaging (user POV)" — the rules
- `docs/vision.md` → Catalog hierarchy + vocabulary
- `docs/conventions.md#vocabulary` — Addon / Commands / UI / Category / Helper /
  Bundle definitions
- `docs/backlog.md` — the packaging map (what's planned, how it's grouped)
- Every `addons/*/addon.yaml` — id, name, commands, category, tags, dependencies,
  helpers, view types
- Every `addons/*/README.md` — user-facing description
- `addons/README.md` — the catalog overview
- `registry/addons.json` — category / subcategory / tags / description / commands
  as the catalog surfaces them
- `registry/helpers.json` — what's a helper vs what's an addon
- `helpers/*/helper.yaml`
- `docs/architecture/2026-08-23-addon-catalog-browse-design.md`,
  `2026-08-25-launcher-catalog-design.md` — catalog UX intent
- `docs/architecture/2026-08-26-tools-launcher-design.md` (ticket 0053),
  `2026-08-26-menubar-design.md` (ticket 0056) — the two other surfaces that
  expose the catalog to non-technical users; check packaging assumptions there
- `docs/architecture/2026-08-27-addon-state-and-config-design.md` — the `config:`
  block in `addon.yaml` is **spec-locked but not yet a real manifest field**
  (`AddonManifest` in `Models.swift` has no `config:` key as of this writing).
  The finding is: does any `addons/*/addon.yaml` already declare a `config:`
  block, and if so does it obey the spec's scalars-only rule (string/int/bool/
  enum — no arrays, no nested)?

## Scope — out

- `.venv/`, `.build/`, `DerivedData/`, `dist/`, `__pycache__/`
- Addon *implementation* (`bin/run` logic) — only the packaging/manifest/naming
- Catalog UI code quality — `code-quality`
- Whether the catalog code matches the view-types ADR — `architecture-drift`
- Security of the install path — `security`

## Ground truth

`AGENTS.md` is the authority on packaging. `vision.md` on the hierarchy.
`backlog.md` must stay consistent with `vision.md` — if `backlog.md` groups
something in a way `vision.md` forbids, the finding is against `backlog.md`.

## Existing tickets in this domain

Cross-check `docs/tickets.md`: **0002** (catalog browse taxonomy/install),
**0004** (first-run full catalog), **0025** (addon dependency declaration),
**0028** (trust badge), **0029** (universal binary requirement), **0031**
(namespaced ids), **0038** (permission disclosure on card), **0043** (min shell
version), **0047** (helpers), **0048** (bundles), **0053** (tools launcher).

## What to check

1. **Name the job, not the scenario.** Every addon id/name is the job
   (`mute-all`, not `call-mute-all`). Flag any scenario-flavored name.
2. **Paired toggles merged.** No two addons that are the on/off of one thing
   (light/dark → one "Dark Mode"). Scan the catalog for toggle pairs shipped
   separately.
3. **Similar converters/formatters clubbed.** No one-zip-per-conversion. If
   multiple addons are "X→Y converters", they should be commands on one addon
   with shared UI.
4. **Unrelated settings NOT force-merged.** The inverse: an addon bundling
   unrelated toggles into one zip just because they're all toggles. Split by user
   mental model.
5. **Helper vs addon.** For anything in `registry/helpers.json` / `helpers/`
   (today: `clock`): would a user want it on its own? If yes it should be an addon
   with a declared dependency, not a helper. If no, helper is right. Check the
   reverse too — an addon that's really just shared plumbing. Note: `nudges` is the
   addon that consumes the `clock` helper — verify that dependency is declared and
   the helper is downloaded/reused, not copied into the `nudges` zip.
6. **Bundle discipline.** If any "bundle" concept appears: it's a multi-addon
   download only, not a catalog level, enable/uninstall stay per addon. "Play" is
   a category of individual addons, never one shelf zip.
7. **UI-ready.** Every addon treats popup UI + speed as part of the job — none are
   pure CLI scripts with no view declared (check `view_types` / `view` in each
   manifest against what the addon does).
8. **View types allow-listed, not shipped.** Manifests allow-list view ids; no
   addon ships pixels or percentages.
9. **window-layouts is one zip.** Not split into snap / zones / spaces addons.
10. **Registry ↔ manifest match.** `registry/addons.json` category / tags /
    description / commands for each addon match that addon's `addon.yaml`. The
    `commands` field is generated — `scripts/sync-registry-commands.sh` (a thin
    wrapper) calls `scripts/sync-registry-commands.py`; CI runs both
    (`--self-test` / `--check`). Run it mentally — is the registry stale? As of
    this writing: **19 addon dirs**, of which **15 are in `registry/addons.json`**
    (the 3 `ui-demo-*` and `window-layouts` are excluded — that gap is expected).
    A *wrong* field on one of the 15 is the finding.
11. **Demo addons.** `ui-demo-confirm` / `ui-demo-form` / `ui-demo-list` exist in
    `addons/` — confirm they are NOT in `registry/addons.json` (last checked: they
    aren't). If any leak into the registry, flag — they aren't catalog products.
12. **backlog.md map.** Does `docs/backlog.md` group planned addons consistently
    with the rules above and with `vision.md`? Flag any planned grouping that
    would violate a packaging rule the moment it ships.
13. **Ids collision-safe.** Ids are flat today. Note (don't re-file — 0031) any id
    that would collide under namespacing, or any non-job-shaped id.

## What to flag

- An addon whose packaging violates an `AGENTS.md` rule (scenario name, split
  toggle pair, one-zip-per-conversion, force-merged unrelated settings) —
  **Major**.
- A helper that should be an addon, or vice versa — **Major**.
- A "bundle" treated as a catalog level, or "Play" as one zip — **Major**.
- `registry/addons.json` out of sync with the `addon.yaml` files — **Minor**
  (unless a command is missing entirely — **Major**, users can't find it).
- Demo/test addons in the user-facing registry — **Major**.
- A `backlog.md` grouping that will violate a rule on ship — **Minor** (it's
  planning, still fixable) — **Major** if scaffolding already started.
- An addon with no UI/view declared for a job that needs one — **Minor**.

## What NOT to flag

- Id namespacing as new work — 0031, tag `covered`.
- Missing permission disclosure on cards — 0038, tag `covered`.
- Bundle mechanism not built — 0048, tag `covered`.
- Addon implementation bugs — out of scope.
- Anything requiring a product decision that isn't in `AGENTS.md` / `vision.md`
  yet — note as **Observation** for discussion, don't score it.
