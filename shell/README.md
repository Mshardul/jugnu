# Shell

Swift sources for **Jugnu.app** (hotkey, palette, menu bar, addon loader).

Design: [`docs/architecture/2026-08-22-shell-design.md`](../docs/architecture/2026-08-22-shell-design.md)

This directory is reserved for the shell-only binary — no addon code ships inside the app.

## JugnuCore (SPM)

```bash
cd shell
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --filter JugnuCoreTests   # default suite (CI uses this)
# live registry/install checks — not CI, uses the network:
swift test --filter JugnuCoreLiveTests
# or from repo root: make verify-live
```

## Jugnu.app (Xcode)

Project: `Jugnu.xcodeproj` (generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)).

```bash
cd shell
# regenerate after editing project.yml:
xcodegen generate
open Jugnu.xcodeproj
# or:
xcodebuild -project Jugnu.xcodeproj -scheme Jugnu -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
```

`App/Info.plist` sets `LSUIElement` (agent app, no Dock icon). HotKey is linked from the app target.

Dev addons without install:

```bash
export JUGNU_ADDON_PATH="$(pwd)/../addons/mic-mute:$(pwd)/../addons/focus-toggle:$(pwd)/../addons/paste-plain"
```

Point `xcode-select` at Xcode once:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Smoke: [`docs/architecture/shell-smoke.md`](../docs/architecture/shell-smoke.md)
