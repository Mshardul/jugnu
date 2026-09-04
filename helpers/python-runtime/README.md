# python-runtime helper

Pinned standalone **CPython** for first-party Jugnu addons. Not a catalog product and not an enable key.

## What it is

- Interpreter only (`bin/python3`)
- Stdlib only — no pip on the user machine
- Installed under `~/.local/share/jugnu/helpers/python-runtime/<version>/` when a consumer declares it

## What it is not

- Not clip-tools (or any) command logic
- Not listed in Browse Catalog
- Not system `/usr/bin/python3`

## How consumers invoke it

The shell sets `JUGNU_HELPER_PYTHON_RUNTIME` to the helper version directory. Addon launchers should:

```bash
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I "$ADDON_ROOT/app"
```

First consumer: **clip-tools** ([spec](../../docs/architecture/2026-09-04-clip-tools-design.md)).

## Dev staging

```bash
scripts/fetch-python-runtime.sh
export JUGNU_HELPER_PYTHON_RUNTIME="$(cd helpers/python-runtime && pwd)"
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I -c 'print(1+1)'
```

Pinned artifact URLs live in `lock.json` (CPython **3.12.14**, python-build-standalone release **20260901**, `install_only_stripped`). The staged interpreter tree is gitignored; package with `scripts/package-helper-python-runtime.sh`.
