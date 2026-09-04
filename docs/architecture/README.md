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
| Shared helpers | Implemented in Core — [addon manifest — Helpers](../addon-manifest.md#helpers) · [ticket 0047](../tickets.md). Empty `registry/helpers.json` until a real helper ships. Catalog-addon deps stay [0025](../tickets.md). |
| Catalog bundles | Deferred separate epic — [ticket 0048](../tickets.md). Vision rule 5 user model only; more product discussion required. |
| Persistent latency logging | Future epic — [ticket 0001](../tickets.md); JSON-lines, capped retention, timing/ids only, no payload |
| Addon management / settings (browse, catalog, Preferences redesign) | Taxonomy/install: [ticket 0002](../tickets.md). Chrome: [ticket 0008](../tickets.md) — [one panel, presets, stack](./2026-08-23-shell-surface-presets.md). Slices: [0005](../tickets.md)–[0007](../tickets.md), [0009](../tickets.md)–[0012](../tickets.md) |
| Shell surface (one panel, presets, stack) | Done — [2026-08-23 spec](./2026-08-23-shell-surface-presets.md) · [ticket 0008](../tickets.md) |
| Convention retrofit (names/comments) | Future — [ticket 0013](../tickets.md) |
| Addon process lifecycle + crash recovery | Draft — under review (revised after review pass) — [2026-08-30 spec](./2026-08-30-addon-process-lifecycle-design.md) · epic [ticket 0057](../tickets.md). Three-class model (`oneshot` / `job` / `daemon`), `AddonProcessHost` keyed by `(addon-id, command-id)`, `AddonRunner` spawn/wait split, crash-durable marker-file reaper, `job` heartbeat watchdog, first-party gate on `lifecycle: daemon`, crash-loop safe mode. Absorbs [0014](../tickets.md), [0026](../tickets.md), [0032](../tickets.md), [0034](../tickets.md), [0036](../tickets.md), [0041](../tickets.md), [0044](../tickets.md). |
| `session` lifecycle class + addon IPC | Stub epic — [ticket 0059](../tickets.md). Cut from 0057 (§11): live process bound to an open panel, bidirectional newline-JSON IPC (`api: 2`), SIGTERM flush hook, multi-panel window management. Gated on the first `session`-shaped addon. No design doc yet. |
| Addon install & upgrade integrity | Stub epic — [ticket 0058](../tickets.md). zip-slip + atomic install + [0018](../tickets.md)/[0025](../tickets.md)/[0029](../tickets.md)/[0031](../tickets.md)/[0043](../tickets.md). No design doc yet. |
| SwiftFormat as commit/CI gate | Future epic — [ticket 0015](../tickets.md) |
| Keep KeyablePanel across hide | Future — [ticket 0016](../tickets.md) |
| Security audit (installer/runner/registry-trust hardening) | Recurring POV audit, not a ticket — [`docs/audit/prompts/security.md`](../audit/prompts/security.md); seeded with a real zip-slip finding in `AddonInstaller.unzip()`. Findings become tickets after a run. |
| View types (viewport catalog) | Approved, implemented — [2026-08-24 spec](./2026-08-24-view-types.md) · [ticket 0045](../tickets.md) · [ADR 0002](decisions/0002-view-types.md) · [plan](../superpowers/plans/2026-08-24-view-types.md) |
| Window management | Approved, implemented — [2026-08-24 `window-layouts`](./2026-08-24-window-layouts.md) · [ticket 0046](../tickets.md) · [plan](../superpowers/plans/2026-08-24-window-layouts.md) |
| Clock helper + nudges | Approved — [2026-08-25](./2026-08-25-nudges-clock-helper-design.md) · [plan](../superpowers/plans/2026-08-25-nudges-clock-helper.md) · [0049](../tickets.md). First real `registry/helpers.json` consumer after [0047](../tickets.md). PNG icons: [0050](../tickets.md). |
| Clipboard | Later |
| Command catalog (inventory) | Living — [../catalog-commands.md](../catalog-commands.md) |
| UI catalog (mini-apps / view assignment) | Living — [../catalog-ui.md](../catalog-ui.md) |
| `python-runtime` helper | Approved — implemented locally — [2026-09-04](./2026-09-04-python-runtime-helper-design.md) · [plan](../superpowers/plans/2026-09-04-python-runtime-helper.md) · [0060](../tickets.md) Done (Release asset upload pending) |
| `clip-tools` (Phase 1 commands) | Approved — Phase 1 implemented — [2026-09-04](./2026-09-04-clip-tools-design.md) · [plan](../superpowers/plans/2026-09-04-clip-tools.md) · [0061](../tickets.md) Done (Transform UI = Phase 2; Release upload pending) |

Process: brainstorm → section approval → write spec here → human review → implementation plan → code.
