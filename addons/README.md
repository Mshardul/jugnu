# Addons

First-party addon **sources** live here. Each addon builds to **one zip** published via GitHub Releases; the catalog is `registry/addons.json`.

Nothing here is bundled inside `Jugnu.app`. Users install zips into `~/.local/share/jugnu/addons/<id>/`.

## v0 packages

| Addon | Commands |
|---|---|
| `mic-mute` | toggle mic input volume |
| `focus-toggle` | Focus / DND (Shortcuts or Control Center) |
| `paste-plain` | clipboard → plain text |
| `battery-eta` | battery percent, charging state, ETA |
| `world-clock` | current time across configured zones |
| `weather-bar` | current temperature and conditions |
| `brew-outdated` | outdated Homebrew formulae and casks |
| `pomodoro` | work / break timer with notification |
| `floating-note` | always-on-top scratchpad (`note` UI pattern) |
| `clipboard-history` | searchable clipboard history (background watcher + sqlite) |
| `ports` | list listening ports (common dev ports first), kill by pid/port |
| `ui-demo-*` | UI host demos (confirm / list / form) |

Package: `scripts/package-addon.sh addons/<id> dist/`

## Hierarchy (user POV)

See [`docs/vision.md`](../docs/vision.md) — **Catalog hierarchy**:

- **Category** — browse/group in the app (not a zip)
- **Addon** — this directory leaf → one zip / one enable key
- **Commands** — palette actions inside the addon (`addon.yaml`)

Club paired toggles and similar converters as commands under one addon. Don’t ship one zip per toggle or per conversion.

**Shared logic:** if two addons need the same capability, either ship that capability as its **own addon** (when users would install it alone) or **include shared files in each zip** (when they would not). See vision packaging rule 4.

Design: [`docs/architecture/2026-08-22-shell-design.md`](../docs/architecture/2026-08-22-shell-design.md)  
Backlog / packaging map: [`docs/backlog.md`](../docs/backlog.md)

Staging nursery (pre-graduation): `../apps/`, `../extensions/macos/`.
