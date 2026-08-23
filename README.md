# Jugnu

**A little light for everything on your Mac.**

Jugnu (Hindi: *firefly*) is a Mac command platform — meant to replace Spotlight + Alfred + Raycast, not wrap them thinly. Small personal light that appears on demand.

| | |
|---|---|
| **App** | Jugnu |
| **Repo / CLI** | `jugnu` |
| **Status** | Shell MVP + addon UI host — Core + `Jugnu` app (SPM), 14 native addons in tree (GitHub Release registry still lists the published set) |
| **Requires** | macOS 14 (Sonoma) or later |
| **License** | [MIT](LICENSE) |

## Shell (Swift)

```bash
cd shell
swift test
```

`make` reads `DEVELOPER_DIR` from `.env` (see `.env.example`), defaulting to `/Applications/Xcode.app/Contents/Developer`.

To launch the menu-bar app, see **Run locally** below. More detail: [`shell/README.md`](shell/README.md). Smoke: [`docs/architecture/shell-smoke.md`](docs/architecture/shell-smoke.md).

## Run locally

You do not install Jugnu from a store for this. Config and addons stay where they are (`~/.config/jugnu`, `~/.local/share/jugnu`).

From the repo root:

```bash
make run
```

That stops any already-running Jugnu, builds this checkout, and launches the new `.app`.

Or open `shell/Jugnu.xcodeproj` in Xcode and press Run.

Jugnu is a menu-bar agent — **no Dock icon, no window on launch**. `make run` can succeed and still look like “nothing opened.” Look for the firefly on the **right of the menu bar**, then Option+Space (or the menu’s **Open Palette**).

A Debug build from a new folder may need Accessibility turned on again: System Settings → Privacy & Security → Accessibility.

`swift run Jugnu` from `shell/` is a quicker loop for Core logic only. It is **not** the real `.app` (no app icon / menu-bar image). Use `make run` to try this product-pass build.

## Install from the site

Not published yet. When there is a download, install steps will live here.

## Dev tooling

```bash
# once
uv sync
uv run pre-commit install   # or: make hooks
make tools-swift            # brew install swiftformat swiftlint if missing

make precommit   # local hooks on all files (Python + SwiftLint)
make lint-swift  # SwiftLint (installs tools if missing)
make ci          # ruff + mypy + codespell + pytest (matches CI check job)
make test
```

CI: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (ruff, mypy, codespell, pytest, semgrep, SwiftFormat, SwiftLint, `swift test`). Pre-commit is the local guardrail; CI is the authoritative gate. Tests are not run on commit.

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
  conventions.md      # standing coding standards
  backlog.md          # platform, gap list, staged leaves
  architecture/       # design specs (shell first)
shell/                # JugnuCore + JugnuUI + Jugnu menu bar app (SPM)
addons/               # first-party addon sources (one zip each)
```

## Docs

- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Coding conventions](docs/conventions.md)
- [Security policy](SECURITY.md)
- [Data privacy policy](PRIVACY.md)
- [Release process](docs/release-process.md)
- [Addon manifest](docs/addon-manifest.md)
- [Vision](docs/vision.md)
- [Backlog](docs/backlog.md)
- [Staging inventory](docs/staging.md) — how `apps/` / `extensions/` relate to addons
- [Architecture](docs/architecture/) — specs land here after design

## What’s here today

**Graduated to native addons** (`addons/`): clipboard-history, battery-eta, brew-outdated, floating-note, pomodoro, weather-bar, world-clock, ports, window-layouts, open-terminal-here, mute-all — rewritten as shell/JXA `exec` entrypoints (no user Python) alongside mic-mute, focus-toggle, paste-plain. The `apps/` Python versions remain as reference implementations, not shipped.

**macOS helpers (`extensions/macos/`, active, not yet addon-wrapped):** airdrop-folder, focus-toggle, mic-mute, quarantine-clear.

**Stubs (README only):** tools-palette, meeting-bar, paste-transform, port-picker, and other planned leaves — see [backlog](docs/backlog.md).

Hotkey shell, YAML addon runtime, and the addon UI host (toast/confirm/list/form/note) are built and tested (`shell/`). Published addons are GitHub Release assets under `addons-v1.0.0`, with `registry/addons.json` pointing at sha256-verified zips — install via the registry, or the dev `JUGNU_ADDON_PATH` override for local addon work. `open-terminal-here` and `mute-all` are in-tree and catalogued; their release zips ship with the next addons release.

## Out of scope (for now)

- Day-one Alfred-class general file-search war (unless designing shell search)
- Merging Tools CLIs into this repo
- Snippet auto-expand in any app (Accessibility tax) — prefer clipboard / hotkey paste first

## Next

1. Palette + addon UI product pass — [spec](docs/architecture/2026-08-23-palette-ui-product-pass.md): search quality, palette + panel visual design, shared design tokens, first-run recommended-set refresh, live-verification test suite
2. Persistent latency logging (future epic, noted in that spec §6)
3. Addon management / settings — Preferences redesign + catalog browse (future epic, noted in that spec §7)
4. Clipboard + window management as first-party addons
