# Docs-consistency audit

## How to run

Fresh agent session. Read this whole file. Work the checklist as todos. Write the
report to `docs/audit/report/pending/YYYY-MM-DD-docs-consistency.md` from
`docs/audit/report/_template.md`. **First check `report/pending/` — if a
`*-docs-consistency.md` already sits there, stop and tell the user.** After
writing the report, update this prompt's row in [`README.md`](README.md) —
Last run = today, Last severity = the worst finding.

## POV

The docs are a graph of cross-references — `vision.md` defines vocabulary that
`conventions.md`, `AGENTS.md`, and `backlog.md` all use; `tickets.md` links to
specs; `architecture/*` docs link to each other and to ADRs. This audit checks
that graph holds: no dead links, no contradictions between docs, no term used one
way here and another way there, no "must stay consistent with X" that has drifted.

Not about whether docs match *code* — that's `architecture-drift`.

## Scope — in

Every tracked `*.md` and doc-like file:

- `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `SECURITY.md`,
  `PRIVACY.md`, `LICENSE`
- `docs/vision.md`, `docs/conventions.md`, `docs/backlog.md`, `docs/ideas.md`,
  `docs/tickets.md`, `docs/addon-manifest.md`, `docs/release-process.md`,
  `docs/meta-docs-cleanup-plan.md`
- `docs/architecture/*.md` including `README.md` and `shell-smoke.md`. The current
  set (verify against `ls`, it grows): `2026-08-22-shell-design`,
  `2026-08-22-addon-ui-speed-design`, `2026-08-23-addon-catalog-browse-design`,
  `2026-08-23-palette-ui-product-pass`, `2026-08-23-shell-surface-presets`,
  `2026-08-24-view-types`, `2026-08-24-window-layouts`,
  `2026-08-25-launcher-catalog-design`, `2026-08-25-nudges-clock-helper-design`,
  `2026-08-26-error-failure-states-design`, `2026-08-26-icon-system-design`,
  `2026-08-26-menubar-design`, `2026-08-26-permissions-privacy-security-design`,
  `2026-08-26-tools-launcher-design`, `2026-08-26-view-types-visual-design`,
  `2026-08-27-addon-state-and-config-design`. The four `2026-08-26-*` epic docs
  and `2026-08-26-view-types-visual-design` were split from / layered onto earlier
  docs — check each older doc points forward (see §6).
- `docs/architecture/decisions/*.md` (ADRs + README)
- `docs/superpowers/plans/*.md`
- `docs/assets/*.md`
- `.github/instructions/jugnu.instructions.md`
- `.github/ISSUE_TEMPLATE/*.md`, `.github/pull_request_template.md`
- `registry/README.md`, `addons/README.md`, `shell/README.md`
- `addons/*/README.md`, `helpers/*/helper.yaml` (description fields)
- `config/jugnu.example.yaml`, `.env.example` (do their comments match the docs?)
- `docs/tickets/` — if this directory exists, decide: intentional (a planned
  per-ticket-file split) or leftover? Nothing in any doc references it. If
  present, Minor — `.gitkeep` + note or delete. If absent, skip.

## Scope — out

- `.venv/`, `.build/`, `DerivedData/`, `dist/`, `__pycache__/`
- Code files (except example configs above)
- Whether docs match code — `architecture-drift`
- Doc prose *style* — not our concern; only correctness and consistency

## Ground truth / precedence

1. `docs/vision.md` is the authority on **product intent and vocabulary**.
2. ADRs (`docs/architecture/decisions/`) are the authority on **locked technical
   decisions**.
3. Among design docs, **newer date wins**; the older one should point forward or
   be marked superseded.
4. `AGENTS.md` is the authority on **agent-ops and packaging rules**.
5. `docs/tickets.md` rows are the authority on **current work status**.

A doc that contradicts something above it in this list is the one at fault.

## Existing tickets in this domain

Cross-check `docs/tickets.md`. Mostly there won't be ticket overlap — doc drift is
rarely ticketed. If `meta-docs-cleanup-plan.md` describes planned doc surgery,
findings inside its scope get tagged `covered by meta-docs-cleanup-plan`.

## What to check

1. **Dead links.** Every markdown link and every `file_path:line` reference in
   every doc — does the target exist? Especially links to `architecture/*` docs,
   ADRs, `superpowers/plans/*`, and code paths in `tickets.md` "Remarks". Known
   trap: several docs point at Swift paths that moved layer — e.g. `ViewType.swift`
   and `Latency/InvokeTrace.swift` are in `JugnuCore`, not `JugnuUI`; the repo also
   had `apps/` and `extensions/macos/` trees that are gone — flag any doc still
   pointing there.
1b. **The `sync-registry-commands` split.** `registry/README.md` and other docs
   name one script; there are two — `sync-registry-commands.sh` (thin wrapper) and
   `sync-registry-commands.py` (generator + self-test). CI runs both. Any doc that
   implies a single script or the wrong one is a Minor finding.
2. **The explicit "must stay consistent" claims.** `AGENTS.md` says the backlog
   packaging map "must stay consistent with vision". `tickets.md` header
   describes a lifecycle (brainstorm → spec under `architecture/` → mark Done
   with link). Check each such claim actually holds.
3. **Vocabulary.** The six locked terms (Addon, Commands, UI, Category, Helper,
   Bundle) are defined in `conventions.md#vocabulary` and used consistently
   everywhere. Flag any doc using "plugin", "extension", "module", "shelf",
   "pack" loosely, or using a locked term with a different meaning.
4. **No parallel agent-ops doc.** `AGENTS.md` line 3 forbids a parallel copy under
   `.github/instructions/` or `.cursor/rules/`. `.github/instructions/jugnu.instructions.md`
   exists — is it a parallel copy (finding) or a thin pointer to `AGENTS.md`
   (fine)? Compare their content.
5. **ADR ↔ design doc agreement.** ADR 0001 (JSON addon boundary) and ADR 0002
   (view types) vs the design docs they came from and any later doc that
   references them. Flag contradictions.
6. **Superseded docs marked.** Where a newer design doc replaces an older one
   (e.g. view-types visual design vs the original view-types spec; the several
   2026-08-26 epics split from the launcher/catalog design), the older doc should
   say so or link forward. Flag unmarked superseded content.
7. **tickets.md internal consistency.** "Depends on" IDs exist. "Done" rows have a
   spec link in Remarks (the header promises this). No two rows describe the same
   work without cross-referencing. Status matches Remarks narrative.
8. **backlog ↔ vision ↔ tickets.** The backlog packaging map matches vision's
   hierarchy. Backlog items that became tickets are marked / linked. Tickets that
   should be in the backlog aren't orphaned.
9. **Dates.** Doc filenames are dated `YYYY-MM-DD`. Does the content's "as of"
   match the filename? Any doc with a future date or a date inconsistent with its
   git history?
10. **README accuracy.** Top-level `README.md`, `addons/README.md`,
    `shell/README.md`, `registry/README.md` — do the addon counts and lists
    agree with each other and with `ls addons/` and `registry/addons.json`? As
    of this writing the numbers reconcile cleanly: **19 `addons/` dirs** = 15
    registry-shipped + 3 `ui-demo-*` + `window-layouts`; `README.md` "15 native
    addons" matches the registry exactly. The known-stale number is **0021's
    body ("11 first-party addons")**. Flag any README that disagrees with the
    15/19 split, and note 0021's count is old (don't re-file — it's a ticket
    body, not a doc claim). Install steps and directory descriptions match
    reality?
11. **CHANGELOG.** Is it maintained? Does it reference versions/tags that exist?
    Consistent with `release-process.md`?
12. **Example / real config.** The global model is live:
    `config/jugnu.example.yaml` → `~/.config/jugnu/jugnu.yaml` (shell/theme/addon
    enable list). The per-addon `~/.config/jugnu/addons/<id>.yaml` is **locked
    in `2026-08-27-addon-state-and-config-design.md` but not implemented** (no
    `config:` field in `AddonManifest`). Check the global file is documented and
    that nothing calls it the place for per-addon knobs; for the per-addon
    model, check whether `conventions.md` / `addon-manifest.md` describe the
    `config:` schema block *as future* vs *as present* — a doc that presents an
    unbuilt feature as current is a finding.
    `.env.example` matches what the code and `SECURITY.md` say about env vars.
    **Re-derive the live `JUGNU_*` set** (grep `environment[` in `shell/Sources/`)
    rather than trusting a hard-coded list — as of this writing it's
    `JUGNU_ADDON_PATH`, `JUGNU_REPO_ADDONS`, `JUGNU_HELPER_CLOCK`,
    `JUGNU_SCREENSHOT_MODE`; `JUGNU_HELPER_PLAY_RUNTIME` is test-only;
    `JUGNU_STATE_DIR` / `JUGNU_CONFIG_DIR` / `JUGNU_LOG_FD` are spec-only. Flag
    `.env.example` or `SECURITY.md` naming vars that don't exist in code, or
    missing ones that do.
13. **Privacy statements agree.** `PRIVACY.md`, `conventions.md` → Privacy and
    trust, `SECURITY.md`, and the logging-related tickets (0001, 0019, 0030,
    0040) all describe the same rules (ids/timings only, no clipboard/args,
    bounded retention). Flag any divergence in the *stated* policy.

## What to flag

- A dead link or broken `path:line` reference — **Minor** (batch), **Major** if
  it's in `AGENTS.md` / `vision.md` / an ADR (agents rely on those).
- A direct contradiction between two docs where precedence is clear — **Major**
  (against the lower-precedence doc).
- A locked term used with the wrong meaning — **Major**.
- A parallel agent-ops doc that duplicates rather than points — **Major**.
- Unmarked superseded doc content — **Minor**.
- `tickets.md` "Depends on" pointing at a non-existent ID, or a "Done" row with no
  spec link — **Minor**.
- backlog / vision packaging mismatch — **Major** (AGENTS.md explicitly requires
  consistency).
- README counts / steps out of date — **Minor**.
- Divergent privacy policy statements across PRIVACY / SECURITY / conventions —
  **Major** (a privacy-first product must state one policy).
- Date inconsistencies — **Minor**.

## What NOT to flag

- Docs not matching code — `architecture-drift`.
- Prose quality, tone, formatting.
- `superpowers/plans/*` being out of date — plans are point-in-time artifacts,
  only flag if a `tickets.md` row links to one as if current.
- Anything `meta-docs-cleanup-plan.md` already plans to fix — tag `covered`.
