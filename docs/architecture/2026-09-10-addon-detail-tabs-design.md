# Jugnu — Addon detail tabs + Installed + config passthrough (0065)

**Date:** 2026-09-10  
**Status:** Approved — shipped (product locks from prefs thread + batched §3–§5)  
**Ticket:** [0065](../tickets.md)  
**Plan:** [2026-09-10-addon-detail-tabs](../superpowers/plans/2026-09-10-addon-detail-tabs.md)  
**Depends on:** Prefs canvas [0064](../tickets.md), permissions vocabulary [0038](../tickets.md) / [0054](../tickets.md) A, [0827 state+config](./2026-08-27-addon-state-and-config-design.md)  
**Absorbs:** Detail **Settings** tab half of 0054 B; 0827 Epic A (shell pipeline) + nudges as first `config:` consumer  
**Not this epic:** Gallery / genie / card visual redesign ([0067](../tickets.md)); Open/`primary` ([0066](../tickets.md)); Hotkeys ([0037](../tickets.md)); prefs cross-addon Permissions inventory (0054 B remainder)

## 0. Purpose

Ship a **complete behavior** surface for inspecting and configuring an installed addon, plus the shell **config/state passthrough** so Settings editors are real. Visual redesign of catalog/detail is explicitly deferred — functional tabs and settings first.

## 1. Product locks

| Topic | Decision |
|---|---|
| Detail tabs | **Overview / Commands / Settings** (Permissions renamed into Settings) |
| Commands → Run | Only when **installed + enabled** |
| Settings entry (gear, prefs Installed) | When **installed** (disabled OK) |
| Deep link | Stack `detail(addonID, tab:)`; gear/Installed → `.settings`; card tap → `.overview` |
| Prefs Addons | **Installed** + **Updates** (no enable/uninstall in prefs) |
| Config | Full [0827](./2026-08-27-addon-state-and-config-design.md) Epic A |
| First consumer | **nudges** with scalar `config:` (below) |
| Visual | Out — stub [0067](../tickets.md) |

### Nudges `config:` (v1)

```yaml
config:
  - key: default_interval_minutes
    type: int
    default: 30
  - key: show_nudge_now_in_manage
    type: bool
    default: true
```

Rows/template remain state yaml under `JUGNU_STATE_DIR`. Config knobs only.

## 2. Flows

1. **Browse → card tap** → detail Overview (+ Install/Enable/Uninstall as today).  
2. **Browse → gear** (installed) → detail Settings.  
3. **Prefs → Addons → Installed → row** → detail Settings.  
4. **Commands → Run** → same invoke path as palette (incl. TCC gate).  
5. **Settings config edit** → write `~/.config/jugnu/addons/<id>.yaml`; next invoke resolves merged map.  
6. **Invalid config on invoke** → block; Open file / Reset defaults; no partial run.

## 3. Architecture

### 3.1 Stack / UI

- `AddonDetailTab`: `overview | commands | settings`
- `ShellViewState.detail(addonID:tab: AddonDetailTab = .overview)`
- `AddonDetailView`: header, lifecycle action row, tab strip, tab body; `onRun(commandId:)`
- Prefs: `PrefsSelection.addonsInstalled`; Installed list from App-supplied `[(id, name, enabled)]`
- Card: gear button → App push Settings
- Grant status: App passes `[(AddonPermission, granted: Bool?)]` into Settings (TCC via `TCCGrantStatus`; non-TCC `nil`)

### 3.2 Config / state (0827)

Honor 0827 without re-litigating: paths, install/uninstall state dir, schema parse, resolver, runner env + `RunRequest.config`, fix/reset UI, validate-addon, manifest docs.

### 3.3 Layering

| Layer | Owns |
|---|---|
| JugnuCore | Schema, resolver, paths, RunRequest.config, manifest field |
| JugnuUI | Detail tabs, prefs Installed list, preference rows for config |
| App | Push/tab, Run, TCCGrantStatus, open/reset config file, list installed |

## 4. Acceptance

1. Three tabs work; Run gated; gear + Installed deep-link Settings.  
2. Prefs Installed has no lifecycle controls.  
3. Config pipeline tests: defaults / syntax block / bad value / unknown key / merge / `{}` when no schema / env vars.  
4. Nudges ships schema; Settings edits persist; invoke receives config.  
5. No gallery/genie.  
6. `cd shell && swift test` green; smoke + CHANGELOG; 0065 Done; 0067 stubbed.

## 5. Phased delivery

1. Detail tabs + Run + stack tab + gear + prefs Installed  
2. 0827 Core pipeline + validate-addon + docs  
3. Settings config editors + malformed recovery UI  
4. Nudges consumer + smoke/CHANGELOG/tickets  

## 6. Related

- [0827 state+config](./2026-08-27-addon-state-and-config-design.md)  
- [Prefs canvas](./2026-09-10-prefs-canvas-design.md)  
- [Permissions disclosure](./2026-09-10-permissions-disclosure-design.md) §5.2  
- [Launcher-catalog §3.3](./2026-08-25-launcher-catalog-design.md) (tabs; gallery deferred to 0067)
