# Addon Manifest

Every published addon must include `addon.yaml` at the root of its package. The manifest is the shell's trusted description of the addon; it must not contain paths or commands that escape the addon directory.

```yaml
id: mic-mute
name: Mic Mute
version: 1.0.0
api: 1
commands:
  - id: toggle
    title: Toggle microphone mute
    subtitle: Mute or unmute input
    keywords: [mic, mute, audio]
entrypoint:
  kind: exec
  path: bin/run
cleanup:
  paths: []
  launchd: []
```

## Required Fields

- `id`: lowercase job identifier using letters, numbers, and hyphens; it must match the addon directory name.
- `name`: user-facing addon name.
- `version`: three-part Semantic Version.
- `api`: protocol major version; published addons currently use `1`.
- `commands`: one or more command descriptors with stable ids and user-facing titles.
- `entrypoint.kind`: `exec`, `jxa`, or `osascript`.
- `entrypoint.path`: relative path to the entrypoint; absolute paths and parent traversal are forbidden.
- `cleanup`: declared addon-owned paths and launchd labels to remove on disable or uninstall.

## Helpers

Optional. A **helper** is shared runtime the user would not install alone (vision rule 4). It is **not** a catalog addon and **not** an enable key. Do not copy helper code into each addon zip. An in-zip binary (e.g. window-layouts AX exec) is not a Helper.

```yaml
helpers:
  - id: play-runtime
    version: 1.0.0
```

Omit `helpers` when the addon needs none. Distinct from catalog-addon `dependencies` ([ticket 0025](tickets.md)).

| Rule | Lock |
|---|---|
| **Declare** | Exact `id` + three-part `version`. No ranges in v0. |
| **On disk** | `~/.local/share/jugnu/helpers/<id>/<version>/` (addons stay under `addons/<id>/`). |
| **When** | Installing an addon: download any listed helper version that is not already on disk. A later addon that lists the same `id`+`version` reuses it. |
| **Trust** | Same as addons: registry URL + sha256, then unpack. Addons never fetch helper URLs. Signing is in the [security audit](audit/prompts/security.md) scope. |
| **Catalog** | Helpers live in `registry/helpers.json`, **not** `addons.json`. Browse Catalog does not list them. No enable key in `jugnu.yaml`. |
| **Run** | For each declared helper, the runner sets `JUGNU_HELPER_<ID>` to that version’s directory (`id` hyphens → underscores, then uppercase: `play-runtime` → `JUGNU_HELPER_PLAY_RUNTIME`). |
| **Offline** | Missing helper and download fails → install or invoke fails with a plain connection error and Retry. Do not hang. |
| **Uninstall** | Removing an addon deletes a helper version only if **no remaining installed addon** lists that `id`+`version`. Other versions stay. |

Helper zip: `helper.yaml` at the root (`id`, `version` — no `commands`, no enable). Unpack into the version directory above.

Play addons wait on this plumbing ([ticket 0047](tickets.md)). Bundles are [0048](tickets.md).

## View types

Shell-owned viewport ids. Do **not** add `width`, `height`, or `percent` fields.

```yaml
view_types: [rows, fields, ask]   # allow-list from the catalog
commands:
  - id: pick
    title: Pick an item
    view: rows                    # must be in view_types
```

Omit `view_types` to get the shell defaults (`rows`, `fields`, `ask`). A command `view` must be in that list. Run JSON may set `"view"` on `ui` to override; unknown ids fail load/run and do not morph.

Catalog, click-outside, and multi-display rules: [view types spec](architecture/2026-08-24-view-types.md). `scripts/validate-addon.sh` rejects unknown ids and pixel/percent fields.

## Validation

Run the dependency-free validator before packaging:

```bash
scripts/validate-addon.sh addons/<addon-id>
```

The packaging helper runs the same validation automatically:

```bash
scripts/package-addon.sh addons/<addon-id> dist/
```

The entrypoint receives JSON on stdin and must return JSON on stdout using `api: 1`. A successful response preserves the compatible shape `{ "ok": true, "message": "..." }`; failures use `{ "ok": false, "error": "..." }`.

See [the shell design](architecture/2026-08-22-shell-design.md) for the full protocol and lifecycle contract.

## Process lifetime (`lifecycle`)

Each **command** may declare how long its process may live. Omit the field to get `oneshot`. An addon-root `lifecycle:` is the default for every command.

| Class | Process lives | Leave / Esc | Quit | Sleep | Re-invoke |
|---|---|---|---|---|---|
| `oneshot` (default) | Until one JSON result, clamped by `oneshotHardCeiling` (10s) | kills | kills | n/a | new spawn |
| `job` | Until a result; must heartbeat | kills | kills (prompt) | kills | `on_reinvoke`: `reuse` or `replace` |
| `daemon` | Until disable / uninstall | no | no | yes | always reuse; launchd-owned |

`session` is reserved. Load and `scripts/validate-addon.sh` reject it with: *session addons are not yet supported.*

```yaml
lifecycle: oneshot          # addon-root default
commands:
  - id: convert
    title: Convert
    lifecycle: job
    on_reinvoke: replace    # default reuse; read for job only
    timeout: 8              # oneshot only; must be ≤ 10
  - id: watch
    title: Watch
    lifecycle: daemon
    daemon:
      program: bin/watch    # relative to the addon root
      args: ["--loop"]
      keep_alive: true      # default true
```

Rules:

- `lifecycle: daemon` is **first-party only** (`keep-awake`, `clipboard-history`). The shell writes `~/Library/LaunchAgents/com.jugnu.<addon-id>.<command-id>.plist`. Do not ship a `.plist`.
- `cleanup.launchd` is filled from daemon commands at disable/uninstall even if the yaml list is empty.
- A `job` must write stdout (a bare newline counts) within 10s of spawn, then at least every 10s, or the shell SIGKILLs it. There is no wall-clock cap.
- `timeout` on a `oneshot` is clamped to 10 seconds.

