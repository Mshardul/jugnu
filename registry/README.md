# Addon registry

`addons.json` is the public catalog the shell fetches for install/update.

Each entry: `id`, `name`, `version`, `api`, `url` (GitHub Release asset), `sha256`, `summary`.

**Later:** a `category` (or equivalent) for browse UI. Catalog hierarchy is Category → Addon (`id` / zip) → Commands. See [vision — Catalog hierarchy](../docs/vision.md).

See [shell design §2](../docs/architecture/2026-08-22-shell-design.md). Entries are added when an addon zip is published — catalog stays empty until then.
