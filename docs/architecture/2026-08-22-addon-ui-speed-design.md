# Jugnu — addon UI host + speed

**Date:** 2026-08-22
**Status:** Approved
**Product lock:** [vision — Surfaces](../vision.md)
**Depends on:** [Shell design](./2026-08-22-shell-design.md) (`api: 1` run protocol)
**Plan:** [Addon UI host P1](../superpowers/plans/2026-08-22-addon-ui-host-p1.md)
**Out of scope here:** Visual brand / illustration system; full context-aware ranking; per-addon custom rendering engines

## 1. Intent

Addons are **jobs with UI**, not silent scripts. The shell must:

1. Host **popup UI** (panels, pickers, forms, toasts, menu-bar status) consistently.
2. Treat **speed** as a hard product constraint.
3. Leave a clean **context hook** for later “right UI for what’s on screen” — without building screen intelligence now.

## 2. Approach (recommended)

**Shell-owned UI + declarative patterns.** Addon entrypoints stay JSON over stdin/stdout. The addon chooses a **UI pattern** and returns **data**; the shell owns windows, focus, motion, theming tokens, and dismiss behavior.

| Approach | Verdict |
|---|---|
| **A. Shell patterns + JSON payloads (this doc)** | **Recommended** — native feel, fast, secure, matches light Swift host |
| B. Arbitrary HTML/JS WebViews per addon | Reject for default path — inconsistent, slower, harder to sandbox |
| C. Load arbitrary SwiftUI bundles from zips | Defer — powerful but signing/versioning/security heavy |

Custom in-zip UI engines are an explicit later exception, not the default.

## 3. Ownership split

| Concern | Shell | Addon |
|---|---|---|
| Palette, hotkey, menu bar chrome | ✓ | |
| Panel window create/focus/dismiss (Esc, click-out) | ✓ | |
| Pattern layouts (list, form, confirm, toast) | ✓ | |
| Theming tokens / reduced-motion respect | ✓ | |
| Latency measurement + budgets | ✓ | |
| Job logic, transforms, system calls | | ✓ |
| Which pattern + payload fields | | ✓ |
| `cleanup` declarations | | ✓ |
| Menu-bar status content (text/icon state) | shell draws | addon supplies state via protocol / push later |

Addons **must not** create their own unmanaged floating windows in v1 of the UI host. Status items go through shell APIs so disable/uninstall can tear them down.

## 4. Interaction patterns (v1 set)

Every command maps to one primary pattern (declared or returned):

| Pattern id | Use when | Example jobs |
|---|---|---|
| **`toast`** | Instant side effect; no further input | mic-mute toggle, paste-plain, dns-flush |
| **`confirm`** | Destructive / irreversible | empty-trash, sleep-now, hosts write |
| **`list`** | Pick one/many from rows (searchable) | process-find, emoji-picker, settings-jump, favorite-folders |
| **`form`** | Few fields then run | password-options, regex-replace recipe, http-status options |
| **`note`** | Persistent editable text, stays open across saves | floating-note (added post-P1; ships in `JugnuCore`/`JugnuUI` alongside confirm/list/form) |
| **`progress`** | Multi-second work with cancel | large-files scan, brew-cleanup, time-machine start |
| **`status`** | Ongoing menu-bar affordance | mute-status, memory-pressure, brew-outdated |

Rules:

- Prefer the **smallest** pattern that finishes the job.
- Same-shape siblings share patterns (all clip-tools converters → usually `toast` or tiny `form`).
- Nested navigation stays inside one panel; do not open a second unmanaged window.

## 5. Protocol sketch (extends `api: 1`)

Keep today’s run shape. Extend the **response** (and optionally request) without breaking toast-only addons.

**Request (today + reserved context):**

```json
{
  "api": 1,
  "op": "run",
  "command": "toggle",
  "args": {},
  "context": {}
}
```

`context` is **empty or omitted in v1**. Shape reserved for later (see §7). Shell never sends screen pixels by default.

**Response — toast (backward compatible):**

```json
{ "ok": true, "message": "Microphone muted" }
```

**Response — open / refresh UI:**

```json
{
  "ok": true,
  "ui": {
    "pattern": "list",
    "title": "Processes",
    "placeholder": "Filter by name",
    "items": [
      { "id": "1234", "title": "node", "subtitle": "PID 1234 · 12% CPU", "actions": ["quit", "copy-pid"] }
    ]
  }
}
```

**Follow-up** (user picks a row / submits a form): shell calls the same entrypoint again with `op: "run"` (or later `op: "ui"`) and `args` carrying `itemId` / field values. Exact `op` naming can freeze in the implementation plan; the invariant is **one entrypoint, JSON in/out, shell-owned chrome**.

Failure stays `{ "ok": false, "error": "…" }` → shell error toast/banner.

`addon.yaml` may declare a default pattern per command (optional); response `ui` overrides when present.

## 6. Speed (first-class)

### Budgets (targets, measure in DEBUG/TestFlight)

| Path | Target | Hard ceiling |
|---|---|---|
| Hotkey → palette first paint | ≤ 50 ms | 100 ms |
| Command → **toast** visible | ≤ 150 ms | 400 ms |
| Command → **panel chrome** visible (skeleton OK) | ≤ 100 ms | 200 ms |
| Panel chrome → useful content | ≤ 300 ms | 800 ms |
| Follow-up action → feedback | ≤ 150 ms | 400 ms |

If content needs longer (brew, disk walk), show **`progress`** within the chrome budget — never a blank hung palette.

### Engineering rules

1. **Shell UI is never blocked on addon I/O** for first chrome: open pattern shell immediately when the command is known to need a panel; fill when JSON returns.
2. **Cold start is the enemy.** Prefer tiny execs; avoid bootstrapping heavy runtimes. Long-lived helper processes are a later optimization, not required for the first three toast addons.
3. Runner timeout for “feels instant” paths should be much tighter than a generous 5s safety net; keep a separate longer timeout for declared `progress` commands.
4. Instrument: `invoke_ts → first_paint_ts → content_ts → dismiss_ts` (log locally; no network).
5. Reduced Motion: respect system setting; motion is hierarchy, not decoration spam.

## 7. Context hook (later — reserve only)

When context-aware UI lands:

- Shell may populate `context` with **opt-in, local, minimal** fields, e.g. `frontApp`, `hasSelection`, `clipboardKind` (`text` \| `image` \| `empty`), never raw passwords (respect concealed pasteboard).
- **No screen capture / OCR of the display by default.** If ever offered, explicit user permission + separate design.
- Addons declare needs in `addon.yaml`, e.g. `context: [clipboardKind, frontApp]`. Shell strips undeclared fields.
- Ranking “which popup to offer” is a **shell** problem; addons stay job-focused.

Privacy one-liner (product): context stays on-device; users can disable context entirely in prefs.

## 8. Phased delivery

| Phase | Ship | Notes |
|---|---|---|
| **P0** | Palette + toast/error from `{ok,message\|error}` | Matches shell MVP; mic-mute / focus-toggle / paste-plain |
| **P1** | UI host: `confirm`, `list`, `form` + budgets instrumentation | Reference addons: e.g. process-find (`list`), password-gen (`form`), empty-trash (`confirm`) |
| **P2** | `progress`, `status` menu-bar API, tighter runner pooling | brew-outdated, mute-status, memory-pressure |
| **P3** | Populate `context` + opt-in ranking | After P1 solid |

Do not block shell MVP on P1 — but **do not** graduate a large backlog of UI-heavy jobs until P1 exists.

## 9. Non-goals

- Pixel-perfect marketing visual system (follow-on).
- Per-addon React/HTML runtimes as the default.
- Context-from-screen in P0–P2.
- Replacing the JSON entrypoint with in-process plugin loading (revisit only if budgets fail with honest measurement).

## 10. Success criteria

1. A `list`-pattern addon opens chrome within budget even when the process is still computing rows (skeleton → content).
2. Toast-only addons need **zero** UI code beyond `{ok,message}`.
3. Disable/uninstall removes any `status` items the shell created for that addon.
4. Protocol remains `api: 1` compatible for toast responses.
5. A future context field can be added to requests without renaming patterns.

## Open choices (frozen)

- Follow-ups use **`op: "run"`** with richer `args` (e.g. `itemId`, form fields) until a second op is clearly needed.
- `addon.yaml` **may** declare default `ui.pattern` per command; optional for P0/P1 — response `ui` wins when present.
- Exact skeleton styling — UI kit follow-on; patterns above are structural only.

## Related

- [Vision — Surfaces](../vision.md)
- [Shell design](./2026-08-22-shell-design.md)
- [Backlog — Platform](../backlog.md)
- Architecture index: [README](./README.md)
