# Shell

Swift sources for **Jugnu.app** (hotkey, palette, menu bar, addon loader).

Design: [`docs/architecture/2026-08-22-shell-design.md`](../docs/architecture/2026-08-22-shell-design.md)

This directory is reserved for the shell-only binary — no addon code ships inside the app.

## JugnuCore (SPM)

```bash
cd shell
swift test                 # default suite — same as CI
# live registry/install checks — not CI, uses the network:
make test-extended         # from repo root
```

Xcode’s developer dir is `DEVELOPER_DIR` in the repo `.env` / `.env.example` (Makefile default is `/Applications/Xcode.app/Contents/Developer`).

## Run locally

`make run` from the repo root stops any existing Jugnu, then builds and launches the Xcode `.app` (icon and menu-bar image included). Config and addons on disk are left alone.

Or open `Jugnu.xcodeproj` and press Run. If you changed `project.yml`, run `xcodegen generate` first.

There is no Dock icon and no window on launch (`LSUIElement`). Use the menu-bar firefly or Option+Space. If it “did nothing,” look at the right of the menu bar — that is the app.

`swift run Jugnu` skips `Assets.xcassets` (see `Package.swift`) — fine for logic checks, not for chrome.

The Xcode project is generated from `project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)). `App/Info.plist` sets `LSUIElement` (agent app). HotKey is linked from the app target.

Published-site install steps will go in the [root README](../README.md) when a download exists.

Dev addons without install:

```bash
export JUGNU_ADDON_PATH="$(pwd)/../addons/jugnu.mic-mute:$(pwd)/../addons/jugnu.focus-toggle:$(pwd)/../addons/jugnu.paste-plain"
```

Point `xcode-select` at Xcode once:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Smoke: [`docs/architecture/shell-smoke.md`](../docs/architecture/shell-smoke.md)
