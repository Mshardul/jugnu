# Architecture specs

Design documents for Jugnu subsystems. Write specs **before** scaffolding runtimes. Standing coding rules (layering, hot path, addon contract) live in [../conventions.md](../conventions.md), not here.

Architecture decisions are recorded in [decisions/](decisions/). Future-work tickets not yet worth a full spec are tracked in [../tickets.md](../tickets.md). Lower-confidence, not-yet-committed ideas live in [../ideas.md](../ideas.md) — no obligation attached, revisited periodically.

| Spec | Status |
|---|---|
| [2026-08-22 Shell design](./2026-08-22-shell-design.md) | Approved |
| [2026-08-22 Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md) | Approved |
| [2026-08-23 Palette + addon UI product pass](./2026-08-23-palette-ui-product-pass.md) | Approved — implemented ([plan](../superpowers/plans/2026-08-23-palette-ui-product-pass.md)); [manual smoke](./shell-smoke.md) remaining |
| [Addon UI host P1 plan](../superpowers/plans/2026-08-22-addon-ui-host-p1.md) | Done (app wired) |
| [Shell MVP plan](../superpowers/plans/2026-08-22-shell-mvp.md) | Done (Core + Xcode app; see [smoke](./shell-smoke.md)) |
| [Shell smoke checklist](./shell-smoke.md) | Automated items verified; walk the 2026-08-23 manual UI checklist on a Mac |
| Context-aware UI (screen/selection) | Later — reserved in UI+speed §7 |
| Addons packaging (detail) | Follow-on if needed beyond shell spec §2 |
| Catalog taxonomy (categories ↔ addons / commands) | Product intent in [vision — Catalog hierarchy](../vision.md); registry `category` field TBD |
| Persistent latency logging | Future epic — [ticket 0001](../tickets.md); JSON-lines, capped retention, timing/ids only, no payload |
| Addon management / settings (browse, catalog, Preferences redesign) | Taxonomy/install: [ticket 0002](../tickets.md). Chrome: [ticket 0008](../tickets.md) — [one panel, presets, stack](./2026-08-23-shell-surface-presets.md). Slices: [0005](../tickets.md)–[0007](../tickets.md), [0009](../tickets.md)–[0012](../tickets.md) |
| Shell surface (one panel, presets, stack) | Done — [2026-08-23 spec](./2026-08-23-shell-surface-presets.md) · [ticket 0008](../tickets.md) |
| Convention retrofit (names/comments) | Future — [ticket 0013](../tickets.md) |
| Cancel in-flight work on leave | Future — [ticket 0014](../tickets.md) |
| SwiftFormat as commit/CI gate | Future epic — [ticket 0015](../tickets.md) |
| Security audit (installer/runner/registry-trust hardening) | Future epic — [ticket 0003](../tickets.md); seeded with a real zip-slip finding in `AddonInstaller.unzip()` |
| Clipboard | Later |
| Window management | Later |

Process: brainstorm → section approval → write spec here → human review → implementation plan → code.
