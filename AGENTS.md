# Agent notes — Jugnu

## Addon packaging (user POV)

Canonical product intent: `[docs/vision.md](docs/vision.md)` → **Catalog hierarchy**.

Use product terms only:

- **Addon** — installable zip / YAML enable unit.
- **Commands** — palette actions inside that addon (`addon.yaml` `commands`).
- **Category** — browse/group taxonomy only (not a zip).

When proposing or accepting addons:

- **Name the job**, not the imagined scenario (`mute-all`, not `call-mute-all`).
- Merge paired toggles into **one** addon (light/dark → Dark Mode), not separate addons.
- Club similar converters/formatters as **commands** on one addon — never one zip per “JSON→CSV”, “CSV→Excel”, etc.
- Don’t merge unrelated settings into one zip just because they are toggles; split by user mental model.
- If two addons share something significant enough in common:
  - **User would want it alone** → make it **its own addon**.
  - **User would not** → **shared file(s)** included in each consuming zip at package time (not a registry product).
- Backlog packaging map: `[docs/backlog.md](docs/backlog.md)` (must stay consistent with vision).

Shell = light Swift host only; addons never bundled in the `.app`. No user Python for published addons.

Do not scaffold addons until packaging for that addon is explicit. Ideas go in the backlog; build later when asked.