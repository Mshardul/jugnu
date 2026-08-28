# Jugnu — addon state dir + config passthrough

**Date:** 2026-08-27
**Status:** Draft — under review
**Depends on:** [Shell design](./2026-08-22-shell-design.md) (`api: 1` run protocol), [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md) (§5 protocol, §6 budgets), [Addon manifest](../addon-manifest.md)
**Related tickets:** 0034 (malformed yaml recovery), 0023 / 0024 (cleanup), 0033 (storage view), 0050 / 0049 (nudges)
**Not this spec:** clipboard-in-request, notify effects, HTTP/keychain services, live-hold process model, theme tokens. All parked — see §8.

## 1. Intent

Two ambient services the shell gives every addon, no download and no opt-in beyond a manifest declaration:

1. **State dir** — a per-addon directory the addon owns for its own data (scores, caches, curated lists, history). Shell creates it, hands its path in the environment, tears it down on uninstall.
2. **Config passthrough** — small user-set knobs (a difficulty, an interval, a default browser). The user hand-edits one small YAML file per addon; the shell parses and validates it against a schema shipped in the addon, and passes the resolved values as JSON in the run request. The addon never parses YAML.

Both have real consumers now: `tic-tac-toe` (this epic's §7) needs a win/loss tally in state and an `ai_difficulty` knob in config; `nudges` already writes its list to a state path and improvises its template settings.

**Split that this spec locks:** *config* is user-set knobs, always scalar, shell-validated. *Data* is addon-managed content of any shape, opaque to the shell, living in the state dir. A collection (a list of cities, folders, hosts blocks, recipes) is always data. The knobs around it are config.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| State dir path | `~/.local/share/jugnu/state/<id>/` — the existing `stateDir` root plus the addon id |
| State dir creation | At **install** time. Exists before the first invoke. |
| State dir env | `JUGNU_STATE_DIR` set on every invoke, always, whether or not the addon uses it |
| State dir cleanup | Unchanged: `cleanup.paths` in `addon.yaml` declares what disable/uninstall removes (0023 / 0024). The state root itself is removed on uninstall. |
| Config file | `~/.config/jugnu/addons/<id>.yaml` — one file per addon, YAML, hand-editable, comments allowed |
| Config schema location | `config:` block in the addon's `addon.yaml`, shipped in the (sha256-verified) zip. The shell holds no central schema store. |
| Config schema types | **Scalars only:** `string`, `int`, `bool`, `enum`. No arrays, no nested objects. |
| Config env | `JUGNU_CONFIG_DIR` = `~/.config/jugnu/addons/<id>` set on every invoke |
| Config in request | Resolved config map passed as `config` on the run-request JSON |
| Missing config file | Not an error. Addon gets the full set of schema defaults. |
| Malformed config file (syntax error) | **Block the invoke.** Shell shows a message naming the addon, with two actions: open-to-edit, reset-to-defaults. (0034 pattern.) |
| Invalid config value (fails schema) | **Block the invoke**, same UI. Not a silent fallback — the user set a value the addon can't honor and should know. |
| Package-time check | `scripts/validate-addon.sh` rejects a malformed `config:` block and any non-scalar type |

### Rejected

- Config in `jugnu.yaml` under `addons.<id>.config` — that file grows unbounded across 100 addons; per-addon files isolate blast radius.
- Addon reads its own YAML — every addon is an any-language binary and would ship a YAML parser; the shell already has one.
- Non-scalar config types — structured user-editable state is where a typo breaks an addon; collections belong in the state dir under the addon's own management.
- Silent default-substitution on a bad value — theme-hex does this for a single cosmetic token; a wrong config value is a user intent the addon can't meet, worth surfacing.
- Lazy state-dir creation — install-time is more predictable and the addon can assume the directory exists.

## 3. State dir

### Path and lifecycle

```
~/.local/share/jugnu/state/<id>/
```

- **Install:** `AddonInstaller` creates the directory (idempotent — reinstall/upgrade leaves existing contents).
- **Every invoke:** `AddonRunner` sets `JUGNU_STATE_DIR` to the absolute path.
- **Disable:** unchanged — `cleanup.paths` entries removed; the state root may or may not be one of them, addon's choice (a background-watcher addon keeps its data, a scratch addon clears it).
- **Uninstall:** `cleanup.paths` removed, then the state root `~/.local/share/jugnu/state/<id>/` removed wholesale.

### Contract

- The addon may create any files or subdirectories under `JUGNU_STATE_DIR`.
- The shell never reads, writes, validates, or schema-checks anything in there.
- Storage-usage visibility is 0033, not this spec.
- No quota in this spec.

### `JugnuPaths` addition

```swift
public func addonStateRoot(id: String) -> URL {
    stateDir.appendingPathComponent(id)
}
```

`clockTimersFile` and `registryCacheFile` are shell-owned state and stay where they are; they are not addon state roots.

## 4. Config passthrough

### 4a. Schema in `addon.yaml`

```yaml
config:
  - key: ai_difficulty
    type: enum
    values: [easy, medium, hard]
    default: medium
  - key: show_scoreboard
    type: bool
    default: true
```

Field rules:

| Field | Rule |
|---|---|
| `key` | lowercase, letters/digits/underscore, unique within the block |
| `type` | one of `string`, `int`, `bool`, `enum` |
| `values` | required iff `type: enum`; non-empty list of strings |
| `default` | required; must itself satisfy `type` / `values` |

`api: 1` unchanged — `config:` is additive and optional. Omit the block → the addon takes no config and the shell passes `config: {}`.

### 4b. User file

`~/.config/jugnu/addons/<id>.yaml`:

```yaml
ai_difficulty: hard
```

- Flat map, keys matching schema `key`s.
- A key not in the schema → treated as invalid config (block + fix/reset). Rationale: catches typos (`ai_dificulty`) rather than silently ignoring them.
- A schema key absent from the file → filled with `default`.

### 4c. Resolution on invoke

1. Read `addon.yaml` `config:` schema (already parsed at addon load).
2. If `~/.config/jugnu/addons/<id>.yaml` is absent → resolved map = all defaults. Go to 6.
3. Parse the file as YAML. Syntax error → **block**, show fix/reset UI. Stop.
4. For each key in the file: must exist in schema, value must satisfy `type` (and be in `values` for `enum`). Any failure → **block**, show fix/reset UI naming the offending key. Stop.
5. Merge: file values over defaults for present keys; defaults for absent keys.
6. Pass the resolved map as `config` on the request JSON. Set `JUGNU_CONFIG_DIR`.

Type coercion: YAML native types only. `type: int` requires a YAML integer scalar (`5`, not `"5"`). `type: bool` requires `true`/`false`. Keeps the validator trivial and the errors unambiguous.

### 4d. Request JSON

```json
{
  "api": 1,
  "op": "run",
  "command": "play",
  "args": {},
  "config": { "ai_difficulty": "hard", "show_scoreboard": true }
}
```

`config` is always present (possibly `{}`). Additive to §5 of the UI-host spec; toast-only addons ignore it.

### 4e. Fix / reset UI

Reuses the 0034 malformed-`jugnu.yaml` mechanism, scoped to one addon file:

- Message: `Config for "<name>" is invalid: <one-line reason>.`
- Action **Open**: reveal / open `~/.config/jugnu/addons/<id>.yaml` in the user's editor.
- Action **Reset**: overwrite the file with a commented template generated from the schema (every key, its default, its allowed values as a comment), then the user re-invokes.
- No auto-retry, no partial run.

### 4f. `JugnuPaths` addition

```swift
public func addonConfigFile(id: String) -> URL {
    home.appendingPathComponent(".config/jugnu/addons/\(id).yaml")
}
public func addonConfigDir(id: String) -> URL {
    home.appendingPathComponent(".config/jugnu/addons/\(id)")
}
```

## 5. Latency

Both services are shell-side native work done in the invoke path before the process spawns:

- State dir: nothing at invoke time (created at install); one `setenv`.
- Config: one small file read + a scalar-only validation loop + one JSON field. Sub-millisecond for a handful of keys.

No new I/O on the hot path that isn't already bounded. The §6 budgets (toast ≤150 ms) are unaffected. The config file read happens synchronously before `process.run()`; if it ever showed up in traces, it moves to run in parallel with process spawn — not expected to be necessary.

## 6. Security / privacy

- State dir: addon already runs with host privilege (0021 is the future boundary); a dedicated directory doesn't widen that. It *narrows* the eventual sandbox story — "addon writes under `JUGNU_STATE_DIR`" is a clean rule to enforce later.
- Config: the shell parses and validates; the addon receives typed JSON it can trust the shape of. A malicious `addon.yaml` schema is bounded by scalars-only + `validate-addon.sh` + the sha256-verified zip.
- Neither service logs anything. No config values, no state contents, ever — consistent with [Privacy and trust](../conventions.md#privacy-and-trust).

## 7. First consumer — `tic-tac-toe` addon

First addon in the **Play** category. Ships as its own zip (Play rule: one id per zip). Separate epic / plan section; listed here because it exercises both services end to end.

### Commands

| Command | Pattern | View | Notes |
|---|---|---|---|
| `play` | (panel) | `canvas` | 1-player vs AI. Default. |
| `play-2p` | (panel) | `canvas` | Hot-seat, two humans, no AI. |

### Gameplay

- 3×3 board, human is X, moves first. Tap an empty cell → shell re-invokes with the move in `args`; addon returns the updated board plus the AI's reply.
- **AI (1p):** medium — take a winning move if available, else block the opponent's winning move, else random empty cell. `system` randomness; no RNG helper (deferred to `dice-roll`).
- `ai_difficulty` config knob: `easy` (always random), `medium` (default, above), `hard` (minimax, never loses).
- Terminal state (win / loss / draw) → result line + play-again affordance; Esc leaves.

### State

`JUGNU_STATE_DIR/scores.json` — cumulative `{ wins, losses, draws }`. Shown on the board if `show_scoreboard` (config, default true). Cleared on uninstall with the state root.

### Config schema (`addon.yaml`)

```yaml
config:
  - key: ai_difficulty
    type: enum
    values: [easy, medium, hard]
    default: medium
  - key: show_scoreboard
    type: bool
    default: true
```

### Minimal UI now, visual pass later

The board renders with placeholder glyphs (text/emoji X and O, plain cell borders) — the same placeholder stance as the current mockups and tickets 0051 / 0052. A real visual design for `canvas` Play content is **0052's** scope; this addon's polish folds in there, not a new ticket.

### `view_types`

```yaml
view_types: [canvas]
```

Click-outside on `canvas` defaults to **ignore** (view-types spec §4) — a mid-game click outside should not discard the board. Esc / Cmd+W leaves.

## 8. Parked — not this spec

Captured so the boundary is explicit. Each returns only when a concrete batch of addons needs it.

| Parked | Why not now |
|---|---|
| `clipboard` in the request (`{kind, text}`) | ~30 addons will want it, but none in this epic; wants to be designed as the whole request-context contract at once, not one field |
| `notify` / `open` / `reveal` response effects | Same — declarative effects layer, no consumer here |
| HTTP / keychain / exec-allowlisted services | Bigger security surface; own pass; 0039 offline handling lives with it |
| Live-hold process model | Speculative; today's fresh-exec-per-invoke is within budget for pickers, forms, and a 3×3 board |
| Theme tokens in the request | Blocked on 0052 locking the token set |
| Log sink (`JUGNU_LOG_FD`) | 0019 / 0030 / 0040 policy unspecced; no consumer; mechanism cheap to add later |
| Non-scalar config, string arrays | No real addon needs structured config; collections are state-dir data |

## 9. Work items

**Epic A — this spec:**

1. `JugnuPaths`: `addonStateRoot`, `addonConfigFile`, `addonConfigDir`.
2. `AddonInstaller`: create `state/<id>/` on install; remove it on uninstall (after `cleanup.paths`).
3. `AddonManifest`: parse and model the `config:` schema block.
4. `AddonRunner`: set `JUGNU_STATE_DIR`, `JUGNU_CONFIG_DIR`; resolve + validate config; put `config` on the request.
5. Config resolution + validation module (scalars only), with the block/fix/reset outcome.
6. Fix/reset UI — reuse 0034 mechanism, per-addon-file scope; schema→template generator.
7. `scripts/validate-addon.sh`: reject malformed / non-scalar `config:` blocks.
8. `docs/addon-manifest.md`: document `config:` and both env vars.
9. Tests: install creates the dir; uninstall removes it; missing file → defaults; syntax error → block; bad value → block; unknown key → block; valid file → merged map on the request; `config: {}` when no schema.

**Epic B — `tic-tac-toe`** (own plan): the addon in §7.
