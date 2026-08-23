# Agent notes — Jugnu

## Git (hard rule)

- **Do not run git** unless the user explicitly asks for a specific git action in that message.
- **Do not** create branches, worktrees, or commits “for isolation” or “to keep main clean.”
- Work on the **current checkout** as-is. No `feature/*` branches, no `.worktrees/`, no proactive `git status` / commit / push.
- Same rule for **any GitHub write** (`gh release create/upload/edit`, `gh pr`, `gh issue`, etc.) — read-only `gh` (`view`, `list`) is fine, but writes need an explicit ask in that message too, even mid-task.

## Addon packaging (user POV)

Canonical product intent: `[docs/vision.md](docs/vision.md)` → **Catalog hierarchy**.

Use product terms only:

- **Addon** — installable zip / YAML enable unit (commands **and/or** popup UI for one job).
- **Commands** — palette / menu actions inside that addon (`addon.yaml` `commands`).
- **UI** — panels, pickers, forms, previews for that addon (same zip).
- **Category** — browse/group taxonomy only (not a zip).

When proposing or accepting addons:

- **Name the job**, not the imagined scenario (`mute-all`, not `call-mute-all`).
- Merge paired toggles into **one** addon (light/dark → Dark Mode), not separate addons.
- Club similar converters/formatters as **commands** (and shared UI) on one addon — never one zip per “JSON→CSV”, “CSV→Excel”, etc.
- Don’t merge unrelated settings into one zip just because they are toggles; split by user mental model.
- If two addons share something significant enough in common:
  - **User would want it alone** → make it **its own addon**.
  - **User would not** → **shared file(s)** included in each consuming zip at package time (not a registry product).
- Treat **popup UI + speed** as part of every job — not CLI-only scripts. Context-aware “right UI for what’s on screen” is a later platform capability; still design addons as UI-ready.
- Backlog packaging map: `[docs/backlog.md](docs/backlog.md)` (must stay consistent with vision).

Shell = light Swift host only; addons never bundled in the `.app`. No user Python for published addons.

Do not scaffold addons until packaging for that addon is explicit. Ideas go in the backlog; build later when asked.
