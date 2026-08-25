# Meta-docs cleanup plan

Decisions from the meta-file review pass (2026-08-24). Each bullet is one action to take. Not yet applied — review only so far.

## AGENTS.md

- §4 "Addon packaging (user POV)" — trim to a pointer only (link to vision.md + conventions.md#vocabulary); delete restated rules (merge toggles, name-the-job, helper/bundle, view types, window family). Keep the "do not scaffold until packaging explicit" line.

## README.md

- §2 status table — keep the "14 native addons in tree" count, but flag for a currency check now (verify it's accurate).
- §6 Dev tooling — trim to one-time setup only (uv sync, pre-commit install, tools-swift); link to CONTRIBUTING.md's Local Checks for the rest.
- §7 Architecture (target) — trim to a pointer at vision.md's Decomposition list.
- §10 What's here today — trim to a pointer at docs/backlog.md's staged-leaves tables.
- §11 Out of scope (for now) — delete entirely; vision.md's Explicit non-goals is canonical.
- §12 Next — delete entirely; docs/backlog.md's Platform build-order table is canonical.

## CHANGELOG.md

- §Added — move "Added accepted backlog entries for X" / "Added project AI guidance" / "Added a backlog prioritization prompt" lines to the Documentation subsection.
- §Documentation — delete ticket-filing/drafted-epic lines ("Filed tickets 0005–0007", "Drafted the ... epic") — that history lives in tickets.md's Created-on dates.
- §App and Tools — delete the 2026-08-22 "Jugnu is a planned native macOS command platform..." line (mission statement, not a change; duplicates vision.md).

## CONTRIBUTING.md

- No changes. Clean.

## PRIVACY.md / SECURITY.md

- No changes to either. Clean.

## docs/vision.md

- No structural changes. §1 Metaphor stays here as canonical owner (README's short duplicate copy is fine as-is, not worth trimming).
- §6 Catalog hierarchy — trim any pure term-definition prose to point at conventions.md#vocabulary (now the canonical glossary); the 4-row Catalog hierarchy table itself stays (different job: ship-unit relationships, not term definitions).

## docs/conventions.md

- §4 Vocabulary — becomes the canonical glossary (has Helper/Bundle/View type/Zone that vision.md's table lacks).
- §8 Hot path — keep the budget table here as the canonical daily-reference copy.
- §15 UI ownership — keep the table here as canonical; architecture/2026-08-23-shell-surface-presets.md §2 gets one added cross-reference line to this section (see below) — not a structural trim, since on closer read §2 there is navigation/stack mechanics, not the same shell/addon ownership split.
- §16 Addon contract — trim to a pointer; addon-manifest.md + ADR 0001 are canonical, stop restating one-zip/no-Python/stdout-shape rules here.
- §19 Privacy and trust — trim to a pointer at PRIVACY.md + keep only engineering-only specifics not stated there (SHA-256 via CryptoKit, cleanup-declared-paths).
- §20 Do not revive — no change; ADR 0001 is historical rationale, this is the living enforcement checklist, both stay.
- Closing paragraph under UI ownership (the click-outside sentence) — trim to a pointer at architecture/2026-08-24-view-types.md §4 instead of restating the dismiss/ignore rule.

## docs/backlog.md

- §4 Packaging-map preamble — trim to a pointer at vision.md §6; keep only backlog-specific framing (e.g. "ids below are capability/job ids...").
- §5 Packaging map table — keep as-is, canonical, no merge.
- §6 (7 detail sub-tables: Meeting/device, Devops/network/dev, Files/clipboard, Window/focus, System QoL, Play, Design) — delete entirely. No merge into §5.
- §7/§8 (Staged leaves apps/ and extensions/macos/ tables) — keep; add a cross-link to docs/staging.md (staging.md explains the process, backlog.md holds the data).
- §10 Out of scope rabbit holes — delete entirely; vision.md's Explicit non-goals is canonical.

## docs/tickets.md

- Done-row Remarks (rows 0005, 0006, 0008, 0009, 0011, 0045, 0046) — trim each to a link (to the spec/plan with full detail) plus at most one short closure clause. Delete the rest of the narrative — it's either already in the linked plan or belongs in CHANGELOG.md.
- Row 0002 Remarks — remove the scope-correction language ("Chrome is not this ticket... Do not add work on titled BrowseCatalogWindow"); keep only the current-scope statement.

## docs/ideas.md

- No changes. Clean.

## docs/staging.md

- Add one cross-link line pointing to docs/backlog.md's §7/§8 staged-leaves tables ("Current inventory: see docs/backlog.md § Staged leaves").

## docs/release-process.md

- No changes. Clean.

## docs/addon-manifest.md

- No changes. Clean. Confirmed as the correct canonical target for conventions.md §16's new pointer.

## docs/architecture/2026-08-22-shell-design.md

- §2 "Addon package + JSON protocol" — trim the addon.yaml field walkthrough to a pointer at addon-manifest.md. Keep the zip-layout tree and run-protocol JSON examples (runtime behavior, not manifest schema).

## docs/architecture/2026-08-22-addon-ui-speed-design.md

- §3 Ownership split table — trim to a pointer at conventions.md §UI ownership (now canonical there).
- §6 Speed/Budgets table — trim to rationale only; conventions.md §Hot path is now the canonical numbers table. Keep the "Engineering rules" subsection (the why behind the budgets) in full.

## docs/architecture/2026-08-23-addon-catalog-browse-design.md

- Header status line — reword for clarity on what's live vs superseded.
- §2 Locked decisions — keep taxonomy/registry/tags/search/install/caching rows in full. Compress the "Browse window" / "Browse vs My Addons split" rows (the separate-titled-window design) to a short historical note pointing at shell-surface-presets.md as the superseding spec.
- §4 B (Browse Catalog UI — new BrowseCatalogWindow) — compress to a short historical summary, not a full section.
- §4 C (palette entry point) — reword to reflect the actual current mechanism (opens in-panel `catalog`, not `BrowseCatalogWindow`).
- §4 D (install-from-browse) — reword for mechanism accuracy; the mechanism itself is still true.
- §6 Success criteria — trim out criteria that reference the dead window model; keep the still-live ones.

## docs/architecture/2026-08-23-palette-ui-product-pass.md

- No changes. Clean — this is the model for what a completed "Approved" spec should look like.

## docs/architecture/2026-08-23-shell-surface-presets.md

- §2 Locked decisions table — keep as-is; add one cross-reference line pointing to conventions.md §15 (UI ownership) for the shell/addon ownership framing.

## docs/architecture/2026-08-24-view-types.md

- No changes. Clean, canonical. (conventions.md gets the trim instead — see above.)

## docs/architecture/2026-08-24-window-layouts.md

- §5 Commands vs backlog.md's packaging-map row — keep both, different jobs (packaging-map row is compressed cross-addon view; §5 is full functional grouping with commentary). No change.
- §7 Out of scope — delete the "Scaffolding this addon in this documentation change" bullet (meta process note, not a product non-goal).

## docs/architecture/README.md

- No changes. Clean.

## docs/architecture/shell-smoke.md

- No changes. Clean.

## docs/architecture/decisions/README.md

- No changes. Clean.

## docs/architecture/decisions/0001-json-addon-boundary.md

- No changes. Clean. Confirmed as correct canonical target for conventions.md §16 and §20 pointers.

## docs/architecture/decisions/0002-view-types.md

- No changes. Clean. Confirmed as correct canonical target.

## addons/*/README.md (11 files)

- Keep, one per addon, no change to the pattern. Different job from registry/addons.json (which is the centralized catalog/browse data source — summary/description for the app's Browse UI). Per-addon README.md is packaging content that ships inside the zip; release-process.md's packaging spec requires it there. Not duplicative — different consumers (browsing the catalog vs. inspecting a downloaded zip).

## apps/*/README.md (19 files, staging/reference-only leaves)

- Keep individual READMEs, one per leaf, same heading/subheading template across all of them.
- apps/README.md becomes an index: lists every leaf (current/planned) with proper status, links to each leaf's own README.
- Not yet defined: the shared template shape itself, and which existing leaf (if any) is closest to the target shape — revisit when we get to this group.

## Not yet reviewed

shell/README.md, registry/README.md, extensions/macos/*/README.md, each app's ticket-backlog.md, .prompts/*.md, .github/ISSUE_TEMPLATE/*.md, .github/pull_request_template.md, .github/instructions/jugnu.instructions.md (already skimmed once, appears clean as a thin redirect stub — not formally closed out).
