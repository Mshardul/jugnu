# Jugnu — `clip-tools` addon

**Date:** 2026-09-04  
**Status:** Approved  
**Depends on:** [python-runtime helper](./2026-09-04-python-runtime-helper-design.md) (implement first), [addon UI + speed](./2026-08-22-addon-ui-speed-design.md), [view types](./2026-08-24-view-types.md), [Helpers](../addon-manifest.md#helpers)  
**Packaging:** one catalog zip id `clip-tools`  
**Inventories:** [catalog-commands](../catalog-commands.md) · [catalog-ui](../catalog-ui.md)  
**Plan:** [2026-09-04-clip-tools](../superpowers/plans/2026-09-04-clip-tools.md)

## 1. Job

Clipboard **text** format / convert / line tools: palette commands that read the clipboard, transform, write back, and toast a short result.

**Not this addon:** `paste-plain` (own shipped zip), images, PDF, QR, calculators, `diff` (own addon unless later folded tiny).

## 2. Phases

| Phase | Focus | In scope |
|---|---|---|
| **1** | Feature integration | As many reliable palette one-shots as practical; oneshot lifecycle; no Transform panel |
| **2** | UI/UX | Text Transform `canvas` panel; buttons invoke the **same** command ops (no second engine) |

This design locks Phase 1. Phase 2 is sketched only so Phase 1 does not paint into a corner.

## 3. Locked product (Phase 1)

| Topic | Decision |
|---|---|
| Zip | One addon `clip-tools`, many `commands:` |
| Runtime | Declares `helpers: [{ id: python-runtime, version: 1.0.0 }]`. **No** vendored interpreter inside the zip |
| Entry | Single `exec` `bin/run` → `$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3` → `app` router |
| Lifecycle | `oneshot` (default) |
| I/O | Clipboard text in → clipboard text out → `{ok:true,message}` or `{ok:false,error}` |
| Modes | Prefer **distinct command ids** for common modes (e.g. pretty vs minify) for Phase 1 searchability |
| UI | None in Phase 1 (toast only via shell message) |
| Python libs | Stdlib first; pure-Python vendors under `app/vendor/` inside **this** zip (e.g. YAML) — not in the helper |
| User Python | Forbidden — helper only |

### Phase 1 command families (target)

Stats/case/lines: `text-stats`, `case`, `sort-lines`, `reverse-lines`, `dedupe-lines`, `trim-lines`, `number-lines`, `join-lines`, `split-lines`, `prefix-suffix`, `cut-field`  

Structured: `json-pretty`, `json-minify`, `csv-pretty`, `yaml-pretty`, `xml-pretty`, `csv-json`, `json-csv`, `yaml-json`, `json-yaml`, `xml-json`, `json-path`  

Encode/id: `base64-encode`, `base64-decode`, `url-encode`, `url-decode`, `html-escape`, `html-unescape`, `jwt-decode`, `uuid`, `timestamp`, `iso-week`, `slugify`, `hash`  

Misc: `tabs-spaces`, `invisible-chars`, `markdown-table`, `extract-emails`, `lorem`, `regex-replace`, `unicode-name`, `md-link`, `clip-clear`  

Exact titles/keywords live in `addon.yaml` at implement time. Defer an op only if it cannot be done reliably with stdlib + one vendored module — do not silently drop without updating [catalog-commands](../catalog-commands.md).

## 4. Architecture (Phase 1)

```
addons/clip-tools/
  addon.yaml
  bin/run                 # resolves JUGNU_HELPER_PYTHON_RUNTIME, execs python -I app
  app/
    __main__.py           # stdin JSON → dispatch
    clipboard.py          # pbpaste / pbcopy wrappers
    ops/                  # one module per family
    vendor/               # optional pure-Python (e.g. yaml)
  tests/
```

**Invoke:** Shell → `bin/run` with `{api:1,op:run,command,args}` on stdin → stdout JSON result only (no stack traces to user).

**Errors:** Invalid JSON, empty clipboard where required, decode failures → plain `error` strings.

## 5. Phase 2 sketch (not this plan’s build)

| Topic | Lock |
|---|---|
| Title | Text Transform |
| View | `canvas` |
| Opens from | command `transform` (+ optional “Open in Transform” later) |
| Behavior | Paste/edit blob; type dropdown or auto-detect (JSON/CSV/YAML/XML/plain); Format / Minify / Convert / Copy — each calls Phase 1 ops |
| Out of panel | PDF, images, QR, calc, paste-plain |

## 6. Success criteria (Phase 1)

1. Addon installs only after `python-runtime` helper is present (shell helper fetch).  
2. Representative commands pass automated tests (ops unit tests + at least one end-to-end stdin JSON fixture without needing a live pasteboard where mocked).  
3. `validate-addon.sh` clean; packaged zip; registry row when publishing.  
4. Catalogs mark commands `shipped` as they land.  
5. Manual: invoke from palette with real clipboard on a Mac.

## 7. Non-goals (Phase 1)

- Text Transform UI  
- Diff / paste-plain absorption  
- Shared Python helper extraction from an in-zip copy (helper is prerequisite, not post-hoc)  
- Session lifecycle / IPC
