# Audit prompts — index

One file per audit lens. The orchestrator ([`../orchestrator.md`](../orchestrator.md))
reads this table to recommend which to run next.

Keep the **Last run** and **Last severity** columns current: update the row when a
report lands in `report/pending/`, not when it moves to `done/`.

| Prompt | Lens | Cadence | Last run | Last severity |
|--------|------|---------|----------|---------------|
| [security](security.md) | Installer / runner / registry-trust / launchd / process spawning / state-dir + config passthrough | Per addons release, min monthly | — | — |
| [architecture-drift](architecture-drift.md) | Code vs `vision.md`, `architecture/*`, ADRs | Monthly | — | — |
| [catalog-hygiene](catalog-hygiene.md) | Addons vs `AGENTS.md` packaging rules + `backlog.md` map | Per addons release | — | — |
| [code-quality](code-quality.md) | `conventions.md` adherence, dead code, known-debt not growing | Monthly | — | — |
| [docs-consistency](docs-consistency.md) | `backlog` ↔ `vision` ↔ `conventions` ↔ `tickets` ↔ `architecture` cross-refs | Monthly | — | — |

Behavior/correctness bugs are **not** a lens here — see [`../README.md`](../README.md)
→ "What this rotation does NOT cover". First-run priority when the whole rotation
is cold: `architecture-drift` and `code-quality` see the most churn
(`docs/architecture/` and `shell/Sources/JugnuUI/` are the hottest trees).

## How each prompt is structured

- **POV** — one line, the lens.
- **Scope** — in / out, enumerated. The important part. Read it exactly.
- **Ground truth** — the docs that define "correct" for this lens.
- **Existing tickets** — IDs in this domain to cross-check against.
- **What to check** — the checklist. One todo per item.
- **What to flag / what not to flag** — the other important part.
- **Output** — always `report/pending/YYYY-MM-DD-<name>.md` from `_template.md`.
