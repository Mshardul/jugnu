# Jugnu shell — design

**Date:** 2026-08-22
**Status:** Approved
**Scope:** Shell architecture, addon packages, registry, v0
**Out of scope here:** Full visual design system / illustration language (follow-on); deep clipboard/window product design

## Locked decisions

| Topic | Decision |
|---|---|
| Host | Native Swift `Jugnu.app` — shell only, as light as practical |
| Addons in binary | **None.** Addons are never shipped inside the `.app` |
| Addon distribution | One **zip per addon**; catalog in this public repo; packages as **GitHub Release** assets |
| Addon runtime | No user-installed Python. Entrypoints: bundled exec in zip, JXA, or osascript (system tools) |
| Protocol | JSON request/response over stdin/stdout (`api: 1`) |
| UI (product) | Addons are **commands + popup UI**, not scripts-only. Shell hosts palette, menu bar, and addon panels/pickers/forms. **Speed** is first-class. Context-aware “right UI for what’s on screen” is **later** (after UI host works). Visual system polish can follow; the **surface** is locked in [vision — Surfaces](../vision.md). |
| UI (v0 slice) | Visual launcher: command palette + menu-bar icon; enough host chrome to open simple addon popups; deepen UX in follow-ons |
| Hotkey | Default non-Spotlight (Option+Space); first-run **opt-in** to ⌘Space with Spotlight guidance; never silent steal |
| Search (v0) | Enabled-addon **commands only** (no apps/files yet; providers pluggable later) |
| Recommended v0 addons | mic-mute, focus-toggle, paste-plain (installed as separate zips, skippable) |
| Config | YAML; enable/disable; everything configurable later including first screen |
| Disable / uninstall | **Proper cleanup** (see lifecycle) |
| Staging | `apps/` + `extensions/macos/` remain nursery; graduate into `addons/` when packaging |

## 1. Big picture

### Runtime

```
Jugnu.app (shell only)
  ├── Hotkey → Palette + Menu bar (quit / open palette / prefs)
  ├── Loads ~/.config/jugnu/jugnu.yaml
  ├── Installed addons: ~/.local/share/jugnu/addons/<id>/
  ├── Registry client → registry/addons.json + Release zip URLs
  └── Runner → JSON protocol → addon entrypoint
```

### This repository

```
shell/                      # Swift sources → Jugnu.app
addons/                     # addon sources; each leaf → one zip
registry/
  addons.json               # catalog (id, version, url, sha256, api, summary)
docs/architecture/          # this spec and follow-ons
config/jugnu.example.yaml
apps/                       # staging nursery (not the runtime layout)
extensions/macos/           # staging nursery
```

### User machine

| Path | Role |
|---|---|
| `Jugnu.app` | Shell only |
| `~/.config/jugnu/jugnu.yaml` | Hotkey, enable/disable, future UI prefs |
| `~/.local/share/jugnu/addons/<id>/` | Unpacked installed addons |
| `~/.local/share/jugnu/helpers/<id>/<version>/` | Shared **helpers** (not catalog addons). Rules: [addon manifest — Helpers](../addon-manifest.md#helpers) |
| GitHub Releases | Zip download source |

## 2. Addon package + JSON protocol

### Zip layout

```
<id>-<version>.zip
  <id>-<version>/           # or <id>/ — packaging must be consistent; prefer <id>/ at root after unpack to addons/<id>/
    addon.yaml              # required
    bin/run                 # or run.jxa / run.sh
    README.md               # optional
```

**Unpack target:** `~/.local/share/jugnu/addons/<id>/` (version recorded in `addon.yaml` and/or a `.jugnu-meta.json` written by the installer).

### `addon.yaml`

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
  kind: exec                # exec | jxa | osascript
  path: bin/run
# Side effects the shell must undo on disable/uninstall:
cleanup:
  paths: []                 # extra files under Application Support, caches, etc.
  launchd: []               # labels if the addon registered agents
  # Future: statusItem, hotkeys registered by addon, etc.
```

Static `commands` are enough for v0. Dynamic `op: list` may be added later under the same `api` major when needed.

### Run protocol (`api: 1`)

**Request** (stdin to entrypoint):

```json
{ "api": 1, "op": "run", "command": "toggle", "args": {} }
```

**Response** (stdout):

```json
{ "ok": true, "message": "Microphone muted" }
```

Failure: `{ "ok": false, "error": "…" }`.

Shell surfaces `message` / `error` lightly. Popup patterns, latency budgets, and context hooks: [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md). Non-zero exit without JSON is treated as failure.

### Registry entry

```json
{
  "id": "mic-mute",
  "name": "Mic Mute",
  "version": "1.0.0",
  "api": 1,
  "url": "https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0/mic-mute-1.0.0.zip",
  "sha256": "<hex>",
  "summary": "Toggle microphone mute"
}
```

Install only after **sha256** matches. Registry lives at `registry/addons.json` in this repo (raw or release-pinned URL configurable later).

## 3. Shell core

### Internal modules (one app, clear boundaries)

| Module | Responsibility |
|---|---|
| **Core** | Config, registry client, installer, command index, runner, hotkey registration, cleanup orchestration |
| **UI** | Palette, menu bar, first-run prompts, prefs hooks — talks only to Core APIs |

Deep UI later replaces/extends **UI** without rewriting Core.

### Config (`~/.config/jugnu/jugnu.yaml`)

```yaml
version: 1
shell:
  hotkey: "option+space"
addons:
  mic-mute: { enabled: true }
  focus-toggle: { enabled: true }
  paste-plain: { enabled: false }
ui: {}                      # reserved
```

- **Installed ≠ enabled.** Disabled addons stay on disk but are omitted from search; cleanup for **running** side effects still runs on disable.
- Missing config → write defaults on first launch.

### Lifecycle + cleanup

| Action | Behavior |
|---|---|
| Discover | Fetch/cache registry |
| Install | Download → verify sha256 → unpack to `addons/<id>/` → optional `enabled: true` |
| Update | Replace files when newer registry version; run post-update hooks if declared later |
| **Disable** | Stop addon background work; remove commands from index; remove any addon-owned UI/hotkeys/agents **declared in `cleanup`**; keep files; set `enabled: false` |
| **Uninstall** | Disable cleanup, **plus** delete addon directory, remove YAML key, delete `cleanup.paths`, unload `cleanup.launchd`, clear installer caches for that id |
| Enable | Set enabled; reindex; start declared background hooks if any (v0 addons are command-only) |

Addons that create side effects **must** declare them under `cleanup` so uninstall is deterministic.

### Hotkey

- Default: **Option+Space** (rebindable in config/prefs).
- First-run offer: switch to **⌘Space** (opt-in only) + Spotlight rebinding guidance.
- If hotkey permission missing: menu bar **Open palette** still works.

### Search (v0)

Fuzzy over title, subtitle, keywords, and `addonId.commandId` for **enabled** installed addons only.

### Permissions

| Permission | When |
|---|---|
| Input Monitoring (or hotkey API equivalent) | Global hotkey |
| Network | Registry + zip download |
| Accessibility | Not required for shell-only; `window-layouts` and similar request it **on first use of that addon** — [window-layouts spec](./2026-08-24-window-layouts.md) |

### Dev override

Config/env may point at a **local** addon directory (repo `addons/<id>`) so development does not require a GitHub Release.

## 4. v0 scope

### In scope

- Swift shell app: hotkey, small palette, menu bar (quit / open palette / prefs hook)
- YAML config; enable/disable/uninstall with cleanup
- Registry + one zip per addon (checksum)
- JSON run protocol `api: 1`
- First-run recommended installs (three zips) + ⌘Space opt-in
- Local addon path for development
- Honest permission UX

### Out of scope (v0)

- Deep UI / configurable first screen (reserve `ui:` only)
- App or file search
- Any addon payload inside `.app`
- Requiring user Python/Homebrew for published addons
- Full clipboard history product / window management product
- Community unsigned addon trust model beyond sha256 (code signing can follow)

### Success criteria

1. Install `.app` alone → palette works; after recommended zips, three commands run with JSON ok/message.
2. Disable → commands gone, no leftover listeners/agents from that addon. Uninstall → files, config, and declared cleanup gone.
3. `.app` remains shell-scale (no bundled addon code).
4. Fourth addon = new zip + registry row; no shell redesign.

### Suggested build order (post-spec approval)

1. Core spike: config + index + run against one **local** addon
2. Minimal UI: palette + menu bar + hotkey
3. Registry install path (zip + sha256)
4. Package mic-mute, focus-toggle, paste-plain as zips
5. First-run recommended + ⌘Space opt-in
6. Cleanup paths tested (disable/uninstall)

## Open choices (non-blocking)

- Exact default string for Option+Space vs Cmd+Shift+Space if Option+Space conflicts on some layouts — prefer Option+Space; document fallback in prefs.
- Registry fetch URL: raw `main` vs release-tagged manifest for reproducibility — prefer **release-tagged** manifest for production installs; raw `main` acceptable for early dev.
- Entrypoint argv vs stdin-only — **stdin JSON** is the contract; optional argv mirror is unnecessary for v0.

## Related docs

- [Vision](../vision.md)
- [Backlog](../backlog.md)
- [Staging](../staging.md)
- [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md)
