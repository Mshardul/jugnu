# Shell

Swift sources for **Jugnu.app** (hotkey, palette, menu bar, addon loader).

Design: [`docs/architecture/2026-08-22-shell-design.md`](../docs/architecture/2026-08-22-shell-design.md)

This directory is reserved for the shell-only binary — no addon code ships inside the app.

## JugnuCore (SPM)

```bash
cd shell
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
```

## Run the menu bar app

```bash
cd shell
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Optional: load unpacked addons from the repo during development
export JUGNU_ADDON_PATH="$(pwd)/../addons/mic-mute:$(pwd)/../addons/focus-toggle:$(pwd)/../addons/paste-plain"
swift run Jugnu
```

Or open `shell/Package.swift` in Xcode, select the **Jugnu** scheme, Run.

`App/Info.plist` sets `LSUIElement` for packaging; the process also uses `.accessory` activation (no Dock icon).

Point `xcode-select` at Xcode once so `swift test` works without `DEVELOPER_DIR`:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
