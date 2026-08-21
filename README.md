# Jugnu

**A little light for everything on your Mac.**

Jugnu (Hindi: *firefly*) is a Mac command platform — meant to replace Spotlight + Alfred + Raycast, not wrap them thinly. Small personal light that appears on demand.

| | |
|---|---|
| **App** | Jugnu |
| **Repo / CLI** | `jugnu` |
| **Status** | Pre-shell — staging inventory + docs |
| **License** | [MIT](LICENSE) |

## Dev tooling

```bash
# once
uv sync
uv run pre-commit install   # or: make hooks

make precommit   # local hooks on all files
make ci          # ruff + mypy + codespell + pytest (matches CI check job)
make test
```

CI: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (ruff, mypy, codespell, pytest, semgrep). Pre-commit is the local guardrail; CI is the authoritative gate. Tests are not run on commit.

## Architecture (target)

1. **Shell** — hotkey palette, search, addon loader, install/uninstall, enable/disable via YAML
2. **Clipboard** — use-and-throw vs full history (privacy-aware)
3. **Window management** — deep feature set + strong UI/UX
4. **First-party addons** — meeting/device QoL, file triage, etc.
5. **Dev ops in the menu bar** — ports, brew, agents, disk pressure, and similar

Focused **addons** (one zip each) over one mega-binary; related actions are **commands** inside an addon; **categories** organize browse. See [vision — Catalog hierarchy](docs/vision.md). Unrelated Tools nursery CLIs stay in their own repo; Jugnu may wrap them as addons.

## Repo layout

```
apps/                 # staged Mac leaves (implemented + stub) — inventory until addon contract
extensions/macos/     # staged Finder / Shortcuts-style helpers
config/               # example Jugnu YAML (enable/disable sketch)
docs/
  vision.md           # product + brand
  backlog.md          # platform, gap list, staged leaves
  architecture/       # design specs (shell first) — none written yet
shell/                # reserved — no scaffold until shell design is approved
addons/               # reserved — first-party addons after shell contracts exist
```

## Docs

- [Vision](docs/vision.md)
- [Backlog](docs/backlog.md)
- [Staging inventory](docs/staging.md) — how `apps/` / `extensions/` relate to addons
- [Architecture](docs/architecture/) — specs land here after design

## What’s here today

**Implemented (Python CLI / small apps):** clipboard-history, battery-eta, brew-outdated, floating-note, pomodoro, weather-bar, world-clock; macos helpers: airdrop-folder, focus-toggle, mic-mute, open-terminal-here, quarantine-clear.

**Stubs (README only):** tools-palette, window-layouts, layout-save, meeting-bar, paste-transform, port-picker, and other planned leaves — see [backlog](docs/backlog.md).

There is **no** hotkey shell, YAML addon runtime, or native app binary yet.

## Out of scope (for now)

- Day-one Alfred-class general file-search war (unless designing shell search)
- Merging Tools CLIs into this repo
- Snippet auto-expand in any app (Accessibility tax) — prefer clipboard / hotkey paste first

## Next

1. Shell architecture design → spec under `docs/architecture/`
2. Spike: hotkey → list → run one staged command
3. MVP shell + YAML enablement
4. Clipboard + window management as first-party addons
