# Architecture specs

Design documents for Jugnu subsystems. Write specs **before** scaffolding runtimes.

Architecture decisions are recorded in [decisions/](decisions/).

| Spec | Status |
|---|---|
| [2026-08-22 Shell design](./2026-08-22-shell-design.md) | Approved |
| [2026-08-22 Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md) | Approved |
| [Addon UI host P1 plan](../superpowers/plans/2026-08-22-addon-ui-host-p1.md) | Implementation plan |
| [Shell MVP plan](../superpowers/plans/2026-08-22-shell-mvp.md) | Active — Core + app in `shell/` |
| [Shell smoke checklist](./shell-smoke.md) | Manual verification |
| Context-aware UI (screen/selection) | Later — reserved in UI+speed §7 |
| Addons packaging (detail) | Follow-on if needed beyond shell spec §2 |
| Catalog taxonomy (categories ↔ addons / commands) | Product intent in [vision — Catalog hierarchy](../vision.md); registry `category` field TBD |
| Clipboard | Later |
| Window management | Later |

Process: brainstorm → section approval → write spec here → human review → implementation plan → code.
