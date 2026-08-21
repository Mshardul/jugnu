# Addons

First-party addon **sources** live here. Each addon builds to **one zip** published via GitHub Releases; the catalog is `registry/addons.json`.

Nothing here is bundled inside `Jugnu.app`. Users install zips into `~/.local/share/jugnu/addons/<id>/`.

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

No addon packages scaffolded until the shell MVP path and addon packaging are planned.
