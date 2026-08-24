# Agent notes — Jugnu

Coding standards: [docs/conventions.md](docs/conventions.md). Product intent: [docs/vision.md](docs/vision.md). Workflow: [CONTRIBUTING.md](CONTRIBUTING.md). This file is the only agent-ops doc — do not add a parallel copy under `.github/instructions/` or `.cursor/rules/`.

## Git (hard rule)

- **Do not run git** unless the user explicitly asks for a specific git action in that message.
- **Do not** create branches, worktrees, or commits “for isolation” or “to keep main clean.”
- Work on the **current checkout** as-is. No `feature/*` branches, no `.worktrees/`, no proactive `git status` / commit / push.
- Same rule for **any GitHub write** (`gh release create/upload/edit`, `gh pr`, `gh issue`, etc.) — read-only `gh` (`view`, `list`) is fine, but writes need an explicit ask in that message too, even mid-task.

## Change discipline

- Inspect nearby implementations, tests, and current user changes before editing. Make the smallest coherent change.
- Preserve changes you did not make. Never reset, checkout, or otherwise discard user work.
- Report what changed, what was validated, and any remaining risks. Never claim an item is complete without executable validation when the environment provides it.

## Addon packaging (user POV)

Canonical product intent: [docs/vision.md](docs/vision.md) → **Catalog hierarchy**. Use product terms only: **Addon**, **Commands**, **UI**, **Category**, **Helper**, **Bundle** (definitions in [docs/conventions.md](docs/conventions.md#vocabulary)).

When proposing or accepting addons:

- **Name the job**, not the imagined scenario (`mute-all`, not `call-mute-all`).
- Merge paired toggles into **one** addon (light/dark → Dark Mode), not separate addons.
- Club similar converters/formatters as **commands** (and shared UI) on one addon — never one zip per “JSON→CSV”, “CSV→Excel”, etc.
- Don’t merge unrelated settings into one zip just because they are toggles; split by user mental model.
- If two addons share something significant enough in common:
  - **User would want it alone** → make it **its own addon** (consumer declares a dependency).
  - **User would not** → a **helper**: shell downloads it the first time an addon needs it; later addons reuse the cache. Not copied into each zip. Not a catalog product.
- **Bundle** = optional multi-addon download, not a fourth catalog level. Enable/uninstall stay per addon.
- **Play** is a **category** of individual addons (dice-roll, hangman, …), not one shelf zip.
- Treat **popup UI + speed** as part of every job — not CLI-only scripts. Context-aware “right UI for what’s on screen” is a later platform capability; still design addons as UI-ready.
- **View types:** the shell owns the viewport catalog ([view types](docs/architecture/2026-08-24-view-types.md)). Addons allow-list ids; they do not ship pixels or percents.
- **Window family:** one zip `window-layouts` ([spec](docs/architecture/2026-08-24-window-layouts.md)). Zones only (max 6), no undo, no scenes. AX-first; SIP stays on.
- Backlog packaging map: [docs/backlog.md](docs/backlog.md) (must stay consistent with vision).

Shell = light Swift host only; addons never bundled in the `.app`. No user Python for published addons.

Do not scaffold addons until packaging for that addon is explicit. Ideas go in the backlog; build later when asked.
