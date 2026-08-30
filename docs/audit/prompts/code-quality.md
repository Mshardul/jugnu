# Code-quality audit

## How to run

Fresh agent session. Read this whole file. Work the checklist as todos. Write the
report to `docs/audit/report/pending/YYYY-MM-DD-code-quality.md` from
`docs/audit/report/_template.md`. **First check `report/pending/` — if a
`*-code-quality.md` already sits there, stop and tell the user.** After writing
the report, update this prompt's row in [`README.md`](README.md) — Last run =
today, Last severity = the worst finding.

## POV

Does the code follow `docs/conventions.md`, and is the known-debt list shrinking
rather than growing? This is not a bug hunt (`/code-review` and the
`architecture-drift` audit cover behavior) — it's about naming, comments,
layering, dead code, and whether the anti-patterns already catalogued as debt
have been copied into new files.

## Scope — in

- `docs/conventions.md` — the standard, every section
- All first-party Swift:
  - `shell/Sources/JugnuCore/`, `shell/Sources/JugnuUI/`, `shell/App/`
  - `shell/TestsExtended/` (separate SPM package, runs in CI) and
    `shell/ScreenshotTests/ScreenshotFlow.swift` — dead/duplicated code here is in
    scope even though ordinary test-coverage adequacy is not
  - `helpers/clock/Sources/`
  - `addons/window-layouts/Sources/`
- Addon scripts: `addons/*/bin/run` (19 addon dirs; `brew-outdated` is JXA, the rest
  bash), `addons/clipboard-history/bin/watch`, `addons/nudges/bin/nudges.js`
- Python: `scripts/*.py`, `conftest.py`, `addons/*/tests/*.py`
- Shell scripts: `scripts/*.sh` (the full set — `build-registry`, `package-addon`,
  `package-helper-clock`, `validate-addon`, `sync-registry-commands`,
  `ensure-swift-tools`, `run-swiftlint`, `run-swiftformat`, `screenshots`,
  `render-appicon`, `extract-screenshots`), `addons/*/tests/*.sh`
- Lint config: `.swiftlint.yml`, `.swiftformat`, `.pre-commit-config.yaml`,
  `pyproject.toml` — do they encode the conventions, and are they actually run
  (check `.github/workflows/ci.yml`)?
- The **known-debt list** — from `docs/conventions.md` and the project memory
  note "Jugnu known-debt table". These are patterns NOT to copy.

## Scope — out

- `.venv/`, `.build/`, `shell/.build/`, `shell/DerivedData/`, `dist/`,
  `__pycache__/`, `.mypy_cache/`, checked-out deps (Yams, HotKey)
- `*.md` files (docs prose — that's `docs-consistency`)
- Generated: `shell/Jugnu.xcodeproj/project.pbxproj`, `Package.resolved`,
  `uv.lock`, `Assets.xcassets/`, `*.svg`, `*.png`, `*.html`
- Test *coverage* adequacy (that's a `/code-review` / pr-test-analyzer job) —
  but dead/duplicated test code is in scope
- Behavior correctness, spec conformance — other audits

## Ground truth

`docs/conventions.md` verbatim. Where it's silent, the dominant pattern in
`JugnuCore` wins (it's the cleanest layer). The known-debt list is an explicit
"these exist, don't copy them, don't re-file them as new" list.

## Existing tickets in this domain

Cross-check `docs/tickets.md`: **0013** (convention retrofit — `///` / `/* */` /
what-comments / "Task N" notes / `handleEsc`→outcome-verb renames / `PrefsView`
into `JugnuUI`), **0015** (SwiftFormat as CI gate). Findings that fall inside
0013's or 0015's stated scope get tagged `covered by 0013` / `covered by 0015` —
the value is spotting *new* drift since those tickets were written, or scope
they missed.

## What to check

1. **Comments.** `conventions.md` limits comments to at most one `//` "why" per
   place. Flag `///` doc comments, `/* */` blocks, what-comments (restating the
   code), and leftover `// Task N` / plan-artifact notes in first-party Swift.
2. **Naming.** Functions named for outcome, not mechanism. Flag `handleX`,
   `onX` (where it's not a real callback), `doX`, `processX` that hide what the
   function decides. Check the known-debt list for the specific names already
   called out.
3. **Layering.** `JugnuCore` imports no SwiftUI / AppKit. `JugnuUI` has no
   app-lifecycle / `NSApplication`. `shell/App/` only for `@main` + lifecycle.
   `PrefsView` in `shell/App/` is known debt (0013) — confirm nothing *new*
   landed in the wrong layer.
4. **Dead code.** Types, funcs, files with zero references. Grep each
   public/internal symbol. Deleted-component ghosts (old `PalettePanelController`
   etc. are gone — check for stragglers referencing them).
5. **Duplication.** The same logic in two places that should share. Especially
   across `JugnuCore` ↔ addon Swift, or repeated across `addons/*/bin/run`.
6. **Known-debt not copied.** For each pattern on the known-debt list, grep for
   new instances in files added/changed since the ticket that recorded it. A new
   copy of a known-bad pattern is the highest-value finding here.
7. **Lint actually enforced.** `.swiftlint.yml` / `.swiftformat` rules match the
   conventions. `ci.yml` runs BOTH `swiftlint lint` and `swiftformat --lint`
   already — but SwiftFormat's CI scope is `shell/Sources shell/Tests
   shell/TestsExtended`, which *excludes `shell/App/`* (ticket 0015 wants App
   included and is still "Not started"). Pre-commit runs swiftlint only, not
   swiftformat. Flag: any convention no linter enforces and code violates; and the
   `shell/App/` SwiftFormat gap as a concrete finding against 0015's scope.
8. **Python / shell scripts.** `ruff` (check + format) runs in CI and pre-commit.
   `codespell` runs in both. `gitleaks` + `detect-private-key` cover secrets.
   `semgrep` (`p/security-audit`, `p/python`) runs in CI on `addons/` only, and
   `ci.yml:52-54` `--exclude-rule`s `python-logger-credential-disclosure` — note
   that carve-out. There is **no `shellcheck`** anywhere — flag that plus any
   `scripts/*.sh` missing `set -euo pipefail`. Addon `bin/run` scripts (19 addon
   dirs) consistent in language choice and error handling.
9. **File size / responsibility.** Any Swift file doing too many jobs — flag as
   Minor with a suggested split, not a mandate.
10. **TODO / FIXME / HACK.** Grep first-party code. Each one: is there a ticket?
    If not, it's a finding (either file it or delete the comment).

## What to flag

- A **new** instance of a known-debt pattern in a file touched after that debt
  was recorded — **Major** (the retrofit tickets are trying to shrink this, not
  hold steady).
- New code in the wrong layer — **Major**.
- Dead code (unreferenced type/func/file) — **Minor** (batch into one cleanup
  ticket).
- `///` / `/* */` / what-comments / "Task N" notes — **Minor**, tag
  `covered by 0013` if in an old file, **Major** if in a file added since 0013.
- A convention that no linter enforces and that code violates — **Minor** plus a
  note: "add lint rule or clean up".
- `TODO`/`FIXME` with no ticket — **Minor**.
- `scripts/*.sh` missing `set -euo pipefail` — **Minor**.
- Duplication that should be shared — **Minor** unless it's already caused a
  divergence bug — then **Major**.

## What NOT to flag

- Known-debt patterns in files that predate the recording ticket — tag
  `covered by 0013` / `covered by 0015` and move on. Do NOT re-file them.
- Formatting the whole tree wants (0015 owns that — a large wrap/comma/import
  rewrite is expected and parked).
- Test coverage gaps — different tool.
- Behavior bugs — `/code-review` or `architecture-drift`.
- Anything in the out-of-scope list.
