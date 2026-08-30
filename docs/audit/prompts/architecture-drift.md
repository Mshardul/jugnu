# Architecture-drift audit

## How to run

Fresh agent session. Read this whole file. Work the checklist as todos. Write the
report to `docs/audit/report/pending/YYYY-MM-DD-architecture-drift.md` from
`docs/audit/report/_template.md`. **First check `report/pending/` — if a
`*-architecture-drift.md` already sits there, stop and tell the user.** After
writing the report, update this prompt's row in [`README.md`](README.md) —
Last run = today, Last severity = the worst finding.

## POV

Does the code still match what the specs say it does? Specs are written before the
code and rarely updated after. This audit walks the other direction: for each
locked design decision, find where the code diverges — a constraint not enforced,
a v0 non-goal that quietly shipped, a spec'd behavior that was cut, a shape the
code grew that no spec describes.

## Scope — in

- **Specs (ground truth):**
  - `docs/vision.md` — product intent, the Catalog hierarchy, the vocabulary
  - `docs/architecture/*.md` — every dated design doc
  - `docs/architecture/decisions/000*.md` — ADRs (JSON addon boundary, view types)
  - `docs/addon-manifest.md` — the manifest contract
  - `docs/conventions.md` — layering rules (JugnuCore vs JugnuUI vs App)
- **Code (checked against the specs):**
  - all of `shell/Sources/JugnuCore/` and `shell/Sources/JugnuUI/`
  - `shell/App/`
  - `addons/window-layouts/Sources/` (has its own spec — window-layouts)
  - `helpers/clock/Sources/` (has its own spec — nudges-clock-helper)
  - every `addons/*/addon.yaml` (manifest conformance)
  - `registry/addons.json`, `registry/helpers.json`
- **Plans** (`docs/superpowers/plans/*.md`) — only to see what a "Done" ticket
  claimed it shipped; the spec is still the authority.

## Scope — out

- `.venv/`, `.build/`, `DerivedData/`, `dist/`, `__pycache__/`
- Test files (except: a spec'd behavior with no test at all is a Minor finding)
- Visual polish / naming / dead code — `code-quality`
- Whether the docs agree with *each other* — `docs-consistency`
- Security specifics — `security` (but "a v0 security non-goal shipped" overlaps;
  report it in whichever audit runs, tag the other)

## Ground truth priority

When a design doc and an ADR disagree, the **ADR wins**. When two design docs
disagree, the **newer date wins**, and that disagreement is itself a
`docs-consistency` finding — note it and move on. A `superpowers/plans/` file
never overrides a spec.

## Existing tickets in this domain

Cross-check `docs/tickets.md` (**re-read each row's Status — they move**). Many
rows are "spec exists, code pending" — those are *known* drift, tag
`covered by 00XX`. Especially: **0013** (convention retrofit / layering —
`PrefsView` should be in `JugnuUI`, still in `shell/App/`), **0014** (cancel
in-flight — spec says leave cancels, code doesn't), **0026** (single invoke
mode — `SingleInstance.swift` is app-level, not this), **0041**, **0044**,
**0045** (view types), **0046** (window-layouts), **0047** (helpers),
**0051–0056** (design epics still "findings only"). Note 0003 was an
audit-shaped ticket and is deleted — any "Depends on 0003" is stale.

The interesting findings are the ones with **no** ticket.

## What to check

1. **Catalog hierarchy (`vision.md`).** Code and `registry/addons.json` use only
   the locked vocabulary — Addon, Commands, UI, Category, Helper, Bundle. No
   fourth catalog level. Bundles (if any exist) are download-only, enable/uninstall
   still per-addon. "Play" is a category of individual addons, not one zip.
2. **Addon manifest contract (`addon-manifest.md`).** Every `addons/*/addon.yaml`
   declares only fields the spec defines. `api:` version matches what
   `ManifestLoader.swift` accepts. Helpers declared per the Helpers section.
   `view_types` / `view` allow-listing matches the view-types ADR (addons
   allow-list ids, never ship pixels/percents).
3. **View types (`2026-08-24-view-types.md` + `2026-08-26-view-types-visual-design.md`,
   ADR 0002).** `shell/Sources/JugnuCore/ViewType.swift` — the ten named types
   are: `seek, palette, ask, fields, rows, grid, board, spread, canvas, rail`
   (plus `landscape` / `portrait` for window-layout sizing and
   `notAllowed(String)` / `unknown(String)` error cases — those don't count
   against the ten). `grid` **is** canonical; do not flag its presence. The
   finding is an *eleventh* named type, or a type used by an addon manifest
   ahead of the review that gates it. Sizing is from `visibleFrame` + point
   clamps, not per-addon dimensions. Click-outside-dismiss behavior matches the
   spec's split (`board`/`spread`/`canvas` excepted). Note: view types has two
   design docs now — the visual-design one is newer; where they disagree that
   is a `docs-consistency` finding, but the code should track the newer.
   Also: `CommandDescriptor` carries **both** `ui: CommandUISpec?` (wrapping
   `UIPattern`) and `view: ViewType?` (`Models.swift:290-296`). Check which the
   shell actually honors, whether real manifests populate both, and whether
   `UIPattern` is legacy that ADR 0002 superseded and should be removed (a
   `code-quality` dead-code + `docs-consistency` ADR cross-check too).
4. **Shell surface (`2026-08-23-shell-surface-presets.md`).** One `KeyablePanel`,
   one panel reused (not recreated — 0016). Navigation follows the launcher tree
   (push child / replace sibling / pop on Esc). Invoke-hotkey home-or-close
   behavior. Toast is a detached HUD, not a stack node. `note` is detached.
   Check `ShellHost.swift`, `ShellStack.swift`, `ShellPreset.swift`,
   `KeyablePanel.swift`.
5. **JSON addon boundary (ADR 0001).** The shell ↔ addon contract is
   JSON-over-stdio only. No addon imports a shell type; the shell never reaches
   into an addon's internals. `RunJSON.swift` / `RunModels.swift` are the whole
   surface.
6. **Layering (`conventions.md`).** `JugnuCore` has no SwiftUI / AppKit import.
   `JugnuUI` has no app-lifecycle code. `shell/App/` is the only place with
   `@main` / `NSApplication`. Flag any file in the wrong layer (0013 already
   names `PrefsView`).
7. **Privacy constraints (`conventions.md` → Privacy and trust).** Logging code
   (`shell/Sources/JugnuCore/Latency/InvokeTrace.swift`, any error/usage log)
   writes ids + timings only — never clipboard text, never command args. Retention
   is bounded where a spec says so.
8. **window-layouts (`2026-08-24-window-layouts.md`).** One zip. Zones only, max
   6. No undo, no scenes. AX-first, SIP stays on. Check
   `addons/window-layouts/Sources/`.
9. **clock helper / nudges (`2026-08-25-nudges-clock-helper-design.md`).** Helper
   is a real `registry/helpers.json` package, downloaded once and reused, not
   copied into the addon zip. `ClockHost.swift` / `ClockClient.swift` match the
   spec's host/client split.
10. **v0 non-goals.** Grep each spec for "non-goal", "v0 does not", "later",
    "future", "out of scope". For each, check the code did *not* quietly build it
    (scope creep) — or did build it without the spec being updated.
11. **Dead specs.** Any `architecture/*.md` describing a component that no longer
    exists in code. `PalettePanelController`, `UIHostController`,
    `BrowseCatalogWindowController`, `SkeletonPanel` are all deleted from
    `shell/` but still referenced throughout
    `docs/architecture/2026-08-23-palette-ui-product-pass.md` and its
    `superpowers/plans/` file — the plan file is a point-in-time artifact
    (leave it), but the `architecture/` doc describing deleted classes as
    current is a finding. The stale spec is a finding.
12. **Untracked shape.** Any sizeable component in `JugnuCore` / `JugnuUI` that no
    spec describes at all — it grew organically. Not necessarily wrong; worth a
    finding so a spec gets written or the code gets questioned.
13. **Menu bar (`2026-08-26-menubar-design.md`, ticket 0056).** The spec is
    "findings only, to be reviewed" — but `shell/App/JugnuApp.swift` +
    `MenuBarController.swift` + `Info.plist` (`LSUIElement`) already ship a menu-bar
    surface. Check what the code does vs what the doc's findings assume; flag any
    behavior the doc explicitly parks that the code built anyway.
14. **Error / failure states (`2026-08-26-error-failure-states-design.md`,
    tickets 0006/0019).** `PanelErrorBanner.swift`, `PanelErrorBanner`,
    `UserFacingError.swift` — does the shipped taxonomy match the spec's
    hang/timeout vs non-zero-exit vs malformed-stdout split? Are raw stderr/stack
    dumps ever surfaced to the user (spec forbids)?
15. **Addon state dir + config passthrough
    (`2026-08-27-addon-state-and-config-design.md`).** **Spec locked, code not
    started** as of this writing: `AddonRunner` sets no `JUGNU_STATE_DIR` /
    `JUGNU_CONFIG_DIR` (`AddonRunner.swift:36-90` — helper vars only),
    `AddonManifest` has no `config:` field (`Models.swift:377-470`),
    `StateStore.swift` exists but is not wired into install or invoke. The
    finding is: (a) has partial work landed that diverges from the
    locked-decisions table (state dir at `~/.local/share/jugnu/state/<id>/`,
    created at *install*, `JUGNU_STATE_DIR` on *every* invoke, `config:` schema
    scalars-only — string/int/bool/enum, no arrays, no nested), or (b) does an
    `addons/*/addon.yaml` already ship a `config:` block the shell can't read.
    If neither, note as an Observation that the whole spec is pending, not a
    Major.
16. **Tools launcher (`2026-08-26-tools-launcher-design.md`, ticket 0053).**
    "Findings only" — the tools-launcher *view page shape* and the viewA-row1
    button are open questions. `grid` already exists in `ViewType.swift` as a
    canonical type (§3) — that is **not** the drift. Check that no
    tools-launcher-specific UI (a dedicated view page, the row-1 button) shipped
    ahead of the 0053 review.
17. **Icon system (`2026-08-26-icon-system-design.md`, ticket 0050).** PNG icons,
    where they live, how they are referenced. Check the addon zips / registry
    against what the spec locks.
18. **Speed budgets (`2026-08-22-addon-ui-speed-design.md`).** The hot-path budget
    numbers and the skeleton-chrome-within-100ms rule — is the invoke path still
    built to them, or has a synchronous step crept in?

## What to flag

- A locked constraint (max 6 zones, ten view types, no fourth catalog level,
  JSON-only boundary, layer separation) violated in code — **Major**.
- A spec'd behavior that was cut and never shipped, with no ticket — **Major**.
- A v0 non-goal built anyway without spec update — **Major** (scope creep) or
  **Minor** if trivial.
- A privacy constraint (ids-only logging, bounded retention) not honored — 
  **Critical** (privacy is a hard constraint).
- A stale spec describing deleted code — **Minor**.
- A component with no spec — **Observation** (or Minor if it encodes real
  product decisions nobody wrote down).
- Manifest field in an `addon.yaml` that the spec doesn't define — **Minor**.

## What NOT to flag

- Drift that a `docs/tickets.md` row already tracks — tag `covered by 00XX`, don't
  re-litigate.
- Docs disagreeing with each other — that's `docs-consistency`.
- Naming / comments / formatting — `code-quality`.
- Design epics still marked "findings only, to be reviewed" (0051–0056) — the
  code deliberately uses placeholders there.
