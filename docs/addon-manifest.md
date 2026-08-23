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
