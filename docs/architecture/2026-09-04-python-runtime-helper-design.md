# Jugnu — `python-runtime` helper

**Date:** 2026-09-04  
**Status:** Approved  
**Depends on:** [Helpers](../addon-manifest.md#helpers) ([ticket 0047](../tickets.md) — Done), [clock helper](./2026-08-25-nudges-clock-helper-design.md) as packaging precedent  
**Packaging:** shared helper id `python-runtime` (not catalog). No enable key.  
**Consumers (first):** [clip-tools](./2026-09-04-clip-tools-design.md)  
**Plan:** [2026-09-04-python-runtime-helper](../superpowers/plans/2026-09-04-python-runtime-helper.md)

## 1. Job

Provide a **pinned, self-contained CPython** on macOS so first-party addons can run Python **without** the user installing Python or Homebrew.

This helper is an **interpreter only**. It does not implement clip-tools (or any) commands. Addon logic stays in the addon zip.

## 2. Locked product

| Topic | Decision |
|---|---|
| Identity | Helper id `python-runtime`, version `1.0.0` (bump on interpreter / security change) |
| Catalog | **Not** in Browse Catalog; `registry/helpers.json` only |
| On disk | `~/.local/share/jugnu/helpers/python-runtime/<version>/` |
| Env | Runner sets `JUGNU_HELPER_PYTHON_RUNTIME` to that version directory |
| Layout inside helper | `helper.yaml` + `bin/python3` (executable entry) + full standalone tree as required by the build |
| Arch | Support Apple Silicon and Intel — universal binary **or** documented dual-arch layout that `bin/python3` selects; do not ship arm64-only |
| Site packages | **Stdlib only** in the helper. Addon-specific pure-Python libs live in the **addon** (`app/vendor/`), not here |
| pip | No `pip install` on the user’s machine. No network from the helper at runtime |
| Updates | New helper **version** + registry row; consumers pin exact `version` in `addon.yaml` |
| Offline | Missing helper + failed download → plain connection error + Retry (existing helper contract) |
| Uninstall | Last-consumer cleanup (existing helper contract) |
| Relationship to clip-tools | Implement **this helper first**; clip-tools declares it and does **not** vendor a second interpreter in-zip |

## 3. Architecture

### 3.1 Source of the interpreter

Use a **pinned** [python-build-standalone](https://github.com/astral-sh/python-build-standalone) (or equivalent) release artifact:

- Lock file in-repo: URL(s) + sha256 per arch (or one universal artifact if available).
- CI / `scripts/fetch-python-runtime.sh` downloads, verifies sha256, stages under `helpers/python-runtime/`.
- Do **not** commit the full interpreter tree to git if size is extreme — commit lock + fetch script; package script assembles the zip (same spirit as building `clock` before zip). Prefer whatever matches repo norms after size check; document the choice in the plan task.

### 3.2 `bin/python3`

A stable entry the addon launcher calls:

```bash
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I "$ADDON_ROOT/app/…" 
```

- `-I` (isolated) where compatible, so user site-packages never leak in.
- Working directory / `PYTHONPATH` set by the **addon** `bin/run`, not by the helper.

### 3.3 Shell changes

**None required** if 0047 already sets `JUGNU_HELPER_*` for any declared helper. Verify with an install of a test consumer (clip-tools) or a tiny fixture addon in tests.

### 3.4 Security / trust

Same as other helpers: registry URL + sha256, unpack under helpers dir, path-safe extract (zip-slip remains security-audit / 0058). Helper is first-party only in v0.

## 4. Non-goals

- Bundling clip-tools ops or PyYAML in the helper  
- Making Python available to third-party addons in v0 (may stay first-party-gated later)  
- Replacing Swift/bash addons that do not need Python  
- Phase 2 UI  

## 5. Success criteria

1. `helpers/python-runtime` packages to a zip; `registry/helpers.json` has `id` + `version` + `url` + `sha256`.  
2. After install of a consumer, `JUGNU_HELPER_PYTHON_RUNTIME` points at a tree whose `bin/python3 -c 'import sys; print(sys.version)'` works offline.  
3. No system `/usr/bin/python3` required.  
4. Docs: this spec, plan, catalog/backlog pointers, CHANGELOG.

## 6. Open implementation details (resolve in plan, not product)

- Exact CPython minor version (prefer current stable 3.12.x or 3.13.x LTS-ish pin).  
- Whether git stores the staged runtime or only the lock + fetch script.  
- Single universal zip vs arch-specific helper zips (prefer one helper id/version that works on both Macs).
