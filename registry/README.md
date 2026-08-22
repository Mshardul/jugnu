# Addon registry

`addons.json` is the public catalog the shell fetches for install/update.

Each entry: `id`, `name`, `version`, `api`, `url` (GitHub Release asset), `sha256`, `summary`.

**Later:** a `category` (or equivalent) for browse UI. Catalog hierarchy is Category → Addon (`id` / zip) → Commands. See [vision — Catalog hierarchy](../docs/vision.md).

See [shell design §2](../docs/architecture/2026-08-22-shell-design.md). Catalog lists published first-party addons (mic-mute, focus-toggle, paste-plain) pointing at the `addons-v1.0.0` Release assets.
