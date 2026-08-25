# Jugnu — clock helper + nudges addon

**Date:** 2026-08-25  
**Status:** Approved  
**Depends on:** [Shell design](./2026-08-22-shell-design.md), [UI host + speed](./2026-08-22-addon-ui-speed-design.md), [Shell surface presets](./2026-08-23-shell-surface-presets.md), [View types](./2026-08-24-view-types.md), [Helpers](../addon-manifest.md#helpers) ([ticket 0047](../tickets.md))  
**Packaging:** shared helper id `clock` (not catalog) + one catalog zip id `nudges`.  
**Follow-up (file after ship):** custom PNG icons on nudge cards (SVG stays deferred).  
**Tickets:** [0049](../tickets.md) (implement) · [0050](../tickets.md) (PNG follow-up — open when 0049 ships)  
**Plan:** [2026-08-25-nudges-clock-helper](../superpowers/plans/2026-08-25-nudges-clock-helper.md)

## 1. Job

**`nudges`** is a mini-tool for recurring wellness-style reminders: a user-owned list of timers, each with emoji, title, firefly message, interval, optional accent, and on/off. Three **presets** (eye-rest, water, stretch) ship as default rows — deletable, restorable. Users can add as many rows as they want.

**`clock`** is the shared timer engine other addons will wire later (kitchen-timer, pomodoro phases, Play clocks). Not a catalog product. Not an enable key.

Surfaces: manage list (same view for add/edit), fire **card** (huge emoji + message), palette commands. Speed and popup UI are part of the job.

## 2. Locked product

| Topic | Decision |
|---|---|
| Scope this round | Ship **`clock` helper + `nudges` addon** together |
| List model | User-defined rows; not a hard-coded trio |
| Presets | Eye-rest, water, stretch — seed on first run; **fully deletable**; **Restore presets** re-seeds them |
| New row | **Add** opens a **prefilled inline editor in the same manage view** (not a big separate form). Prefill from **new-nudge template** |
| Row fields | `emoji`, `title`, `message`, `interval`, optional `accent`, `enabled` |
| Template | Same shape as a row (minus id/enabled). Editable via **config file** and **Advanced** UI. **Reset template** restores factory seed |
| Voice | Firefly / playful — kind wit, not corporate wellness |
| Fire UI | Detached **card**: huge emoji, message, soft accent wash; stays until dismiss (Esc / close). No settings on the card |
| Icons this round | **Emoji only**. PNG later (ticket after ship). SVG deferred |
| Scheduler lifetime | Fire **only while Jugnu is running**. Schedules **persist** across relaunch; no catch-up spam on launch; no fire when quit |
| Quiet hours | Out of this round |
| Card snooze | Out of this round (helper may expose snooze API for later) |
| ≠ other timers | Not pomodoro, not kitchen-timer, not stopwatch — shared helper, separate products |

### Default presets (seed)

| Id key | Emoji | Title (indicative) | Message flavor | Default interval |
|---|---|---|---|---|
| eye-rest | 👀 | Eyes | Firefly look-away line | 20 min |
| water | 💧 | Water | Firefly hydrate line | 45 min |
| stretch | 🧘 | Stretch | Firefly uncurl line | 60 min |

Exact copy can be tuned at implement time; tone stays firefly.

### Factory new-nudge template (indicative)

Emoji `✨`, title `New nudge`, short firefly message, interval 30 min, no accent (or a neutral default).

## 3. Architecture

### 3.1 `clock` helper (shared runtime)

| Rule | Lock |
|---|---|
| Identity | Helper id `clock` in `registry/helpers.json`; `helper.yaml` at zip root |
| Catalog | **Not** listed in Browse Catalog; no enable key |
| On disk | `~/.local/share/jugnu/helpers/clock/<version>/` per [addon-manifest Helpers](../addon-manifest.md#helpers) |
| Consumers | Declare `helpers: [{ id: clock, version: … }]` — first is `nudges` |
| Responsibility | Timer **CRUD**, pause/resume, persist schedules, report **due** timers, mark fired. Generic: no emoji/copy |
| Lifetime | No background agent when Jugnu is quit. Shell drives the tick loop only while the app runs |

**Helper ops** (JSON request/response on the helper exec stdin/stdout, same spirit as addon `api: 1`; keep stable for later consumers):

- `upsert` — create/update timer by id  
- `cancel` — remove by id  
- `pause` / `resume` — one id or `group`  
- `list`  
- `due` — timers with `nextFire ≤ now`, enabled, not paused  
- `mark-fired` — advance repeating interval or complete one-shot  
- `snooze` — API present; nudges UI ignores this round

**Timer record (helper-owned):**

- `id` — globally unique; nudges uses `nudges:<rowId>`  
- `kind` — `interval` \| `one-shot`  
- `intervalSeconds` (interval) or `fireAt` (one-shot)  
- `enabled`, `paused`  
- `nextFire`  
- `target` — `{ "addon": "<id>", "command": "<id>" }` (shell invokes this on fire)  
- optional `group` — e.g. `nudges` for pause-all

### 3.2 Shell `ClockHost`

While `Jugnu.app` is running:

1. Periodically (or via RunLoop timer) ask helper for `due`.  
2. For each due timer, invoke `target` via existing addon runner (`api: 1`).  
3. On success (or after presenting UI), `mark-fired`.  
4. If invoke fails, plain user-facing error; do not tight-loop the same due row — backoff or leave due until next tick per plan.

Start the host loop when Jugnu finishes launching **if** any timer exists on disk **or** any enabled installed addon declares `clock`. Stop the loop when the app quits (no orphan process).

### 3.3 `nudges` addon (catalog)

| Layer | Owns |
|---|---|
| Row list + template | Addon state/config under addon state dir; human-editable |
| Presets / Restore / Reset template | Addon |
| Sync | List edits upsert/cancel matching `nudges:<rowId>` timers on `clock` |
| Fire presentation | Returns UI descriptor for **card** pattern |
| Personality | Emoji, title, message, accent |

Uninstall: `cleanup` removes addon state; helper version removed only if no other consumer (0047). Cancel all `nudges:*` timers on uninstall/disable.

## 4. UI patterns and view types

### 4.1 New detached pattern: `card`

Today’s `note` is an editable scratchpad (`NotePanel` + TextEditor). Nudge fire is **display-only**. Do **not** overload `note` into a poster.

| Topic | Lock |
|---|---|
| Pattern | `card` — new `UIDescriptor` pattern |
| Window | Detached `NSPanel` (same family as note: not an in-panel stack push) |
| Content | Huge emoji (dominant), message line, optional accent wash / tint |
| Chrome | Minimal; Esc / close dismisses; **no save**; nothing persists |
| Click-outside | Dismiss (ephemeral delight, not a board) |
| Duplicate fire | Same row already showing → focus/replace that card; do not stack |

`note` stays scratchpad-only (`persist` true/false unchanged).

### 4.2 Manage view

| Topic | Lock |
|---|---|
| Pattern | In-panel `list` / `form` / `rows` / `fields` as fits (prefer **one** manage surface) |
| Add | Prefills from template **inline in the same view** |
| Advanced | Gated section or command: edit template; reveal/open config file path |
| Restore presets | Command or list action — re-adds missing preset rows (does not wipe custom rows) |

Exact list/Add chrome layout: deferred visual pass; behavior above is locked.

### 4.3 View types allow-list (`nudges`)

```yaml
id: nudges
helpers:
  - id: clock
    version: 1.0.0   # exact version at ship
view_types: [rows, fields, ask]   # adjust if manage UI needs board; card is detached like note (no view-type size)
```

`card` is detached geometry (like `note`): not chosen via addon pixel yaml; shell owns frame (compact poster, clamped).

## 5. Commands (family; same zip)

| Command id | Role |
|---|---|
| `manage` | Open manage list (Add / edit / enable) |
| `nudge-now` | Pick a row → show its card immediately |
| `pause` | Pause all `nudges` group timers via helper |
| `resume` | Resume all `nudges` group timers |
| `restore-presets` | Re-seed eye / water / stretch if deleted |
| `advanced` | Template editor + reveal config file |

Per-row enable and interval live on the manage surface, not as one palette command each.

## 6. Data (addon-owned)

**Row:**

```json
{
  "id": "uuid-or-stable-key",
  "emoji": "👀",
  "title": "Eyes",
  "message": "Glow somewhere farther away for a bit.",
  "intervalSeconds": 1200,
  "accent": "#…",
  "enabled": true,
  "fromPreset": true
}
```

**Template:** same fields except `id`, `enabled`, `fromPreset`.

**Config:** single YAML file under the addon state dir (`nudges.yaml`: `template` + `rows`). Advanced UI read/writes that file. Corrupt file → keep last-good in memory if available, else re-seed presets + plain toast; never crash the shell.

## 7. Errors

- Validation on save (empty message, non-positive interval) → inline on the row  
- Helper missing/offline → plain connection/install error + Retry (0047)  
- Helper timer missing for a row → recreate on next sync  
- User-facing copy only through existing error patterns — no paths, stacks, or “exited 1”

## 8. Testing

- Helper: upsert/pause/resume/cancel; no due when paused; persist reload; mark-fired advances interval  
- Nudges: seed presets; Add from template; Restore presets; disable ↔ timer sync; uninstall cancels `nudges:*`  
- Protocol/UI: fire → `card` descriptor (emoji, message, accent); dismiss discards  
- Manual: short interval, card appears, dismiss, Add custom, Pause all, Restore presets  

## 9. Out of scope (this round)

- PNG / SVG icons (PNG ticket after ship)  
- Fire when Jugnu is quit / launchd agent  
- Catch-up cards for every missed fire on launch  
- Quiet hours  
- Card snooze UI  
- Wiring kitchen-timer / pomodoro / Play (helper API must not block them)  
- Custom copy marketplace / GIF packs  

## 10. Success

1. Install `nudges` pulls `clock` helper once; Browse Catalog does not list `clock`.  
2. Three presets appear; user can delete, restore, add more, edit template under Advanced.  
3. While Jugnu runs, enabled rows fire a visually strong emoji card with firefly copy.  
4. Quit stops firing; relaunch resumes schedules without dumping a stack of missed cards.  
5. Helper API is reusable by a later one-shot timer addon without forking scheduler code.
