# Addons

First-party addon **sources** live here. Each addon builds to **one zip** published via GitHub Releases; the catalog is `registry/addons.json`.

Nothing here is bundled inside `Jugnu.app`. Users install zips into `~/.local/share/jugnu/addons/<id>/`.

Design: [`docs/architecture/2026-08-22-shell-design.md`](../docs/architecture/2026-08-22-shell-design.md)

Staging nursery (pre-graduation): `../apps/`, `../extensions/macos/`.

No addon packages scaffolded until the shell spec is approved and packaging is planned.
