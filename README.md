# Jugnu

**A little light for everything on your Mac.**

Jugnu (Hindi: *firefly*) is a Mac command platform — meant to replace Spotlight + Alfred + Raycast, not wrap them thinly. Small personal light that appears on demand.

| | |
|---|---|
| **App** | Jugnu |
| **Repo / CLI** | `jugnu` |
| **Status** | Shell MVP + addon UI host — Core + `Jugnu` app (SPM), 11 native addons shipped via GitHub Release registry |
| **License** | [MIT](LICENSE) |

## Shell (Swift)

```bash
cd shell
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
swift run Jugnu   # or open Package.swift in Xcode, select the Jugnu scheme
```

See [`shell/README.md`](shell/README.md) and smoke checklist [`docs/architecture/shell-smoke.md`](docs/architecture/shell-smoke.md).

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
shell/                # JugnuCore + JugnuUI + Jugnu menu bar app (SPM)
addons/               # first-party addon sources (one zip each)
```

## Docs

- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Data privacy policy](PRIVACY.md)
- [Release process](docs/release-process.md)
- [Addon manifest](docs/addon-manifest.md)
- [Vision](docs/vision.md)
- [Backlog](docs/backlog.md)
- [Staging inventory](docs/staging.md) — how `apps/` / `extensions/` relate to addons
- [Architecture](docs/architecture/) — specs land here after design

## What’s here today

**Graduated to native addons** (`addons/`): clipboard-history, battery-eta, brew-outdated, floating-note, pomodoro, weather-bar, world-clock, ports — rewritten as shell/JXA `exec` entrypoints (no user Python) alongside mic-mute, focus-toggle, paste-plain. The `apps/` Python versions remain as reference implementations, not shipped.

**macOS helpers (`extensions/macos/`, active, not yet addon-wrapped):** airdrop-folder, focus-toggle, mic-mute, open-terminal-here, quarantine-clear.

**Stubs (README only):** tools-palette, window-layouts, layout-save, meeting-bar, paste-transform, port-picker, and other planned leaves — see [backlog](docs/backlog.md).

Hotkey shell, YAML addon runtime, and the addon UI host (toast/confirm/list/form/note) are built and tested (`shell/`). All 11 addons above are published as GitHub Release assets under `addons-v1.0.0`, with `registry/addons.json` pointing at real sha256-verified zips — install via the registry, or the dev `JUGNU_ADDON_PATH` override for local addon work.

## Out of scope (for now)

- Day-one Alfred-class general file-search war (unless designing shell search)
- Merging Tools CLIs into this repo
- Snippet auto-expand in any app (Accessibility tax) — prefer clipboard / hotkey paste first

## Next

1. Palette + addon UI product pass — [spec](docs/architecture/2026-08-23-palette-ui-product-pass.md): search quality, palette + panel visual design, shared design tokens, first-run recommended-set refresh, live-verification test suite
2. Persistent latency logging (future epic, noted in that spec §6)
3. Addon management / settings — Preferences redesign + catalog browse (future epic, noted in that spec §7)
4. Clipboard + window management as first-party addons
