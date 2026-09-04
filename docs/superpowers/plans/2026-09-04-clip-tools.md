# `clip-tools` Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship catalog addon `clip-tools` Phase 1 — many clipboard text transform **commands** on one zip, running on the `python-runtime` helper, toast-only (no Transform panel).

**Architecture:** Single `exec` entrypoint resolves `$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3`, runs `app` router on `api: 1` JSON, dispatches to `app/ops/*`. Clipboard via `pbpaste`/`pbcopy`. Pure-Python vendors (e.g. YAML) live under `app/vendor/`, not in the helper. Phase 2 UI is out of scope.

**Tech Stack:** Python 3.12+ (helper), bash `bin/run`, `addon.yaml`, unittest/pytest against ops with mocked clipboard where possible, `scripts/validate-addon.sh`, `scripts/package-addon.sh`.

**Spec:** [docs/architecture/2026-09-04-clip-tools-design.md](../../architecture/2026-09-04-clip-tools-design.md)

**Prerequisite:** [2026-09-04-python-runtime-helper](./2026-09-04-python-runtime-helper.md) complete enough that `JUGNU_HELPER_PYTHON_RUNTIME` works locally (ticket 0060). Do not start Task 2 until that smoke passes.

## Global Constraints

- Addon id `clip-tools`; declares `helpers: [{ id: python-runtime, version: 1.0.0 }]`.
- **No** vendored CPython inside this zip.
- Do not absorb `paste-plain`; do not implement images/PDF/QR/calc/diff/Transform UI.
- User-facing errors: plain `{ok:false,error}` — never stack traces on stdout.
- **Git:** do not create commits unless the user explicitly asked (repo `AGENTS.md`). Skip “Commit” steps when not requested.
- Do not `gh release` / registry publish unless the user explicitly asked.

---

## File map

| Path | Responsibility |
|---|---|
| `addons/clip-tools/addon.yaml` | Commands + helpers declaration |
| `addons/clip-tools/bin/run` | Launch helper python `-I` on `app` |
| `addons/clip-tools/app/__main__.py` | Stdin JSON → dispatch |
| `addons/clip-tools/app/clipboard.py` | Read/write pasteboard |
| `addons/clip-tools/app/ops/*.py` | Transform implementations |
| `addons/clip-tools/app/vendor/` | Optional pure-Python (PyYAML-compatible, etc.) |
| `addons/clip-tools/tests/` | Unit tests for ops + router |
| `addons/clip-tools/README.md` | Dev invoke examples |
| `registry/addons.json` | Row when publishing |
| `docs/catalog-commands.md` | Flip shipped markers |
| `docs/catalog-ui.md` | Phase 1 = toast only; Transform remains draft |
| `CHANGELOG.md` | Added clip-tools |

---

### Task 1: Confirm helper prerequisite

**Files:** none (verification only)

- [x] **Step 1: Verify python-runtime**

```bash
export JUGNU_HELPER_PYTHON_RUNTIME="$(cd helpers/python-runtime && pwd)"
test -x "$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3"
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I -c 'import sys; assert sys.version_info >= (3, 12)'
```

Expected: exit 0. If missing, stop and finish the python-runtime plan first.

- [x] **Step 2: Confirm ticket 0060 is Done (or local equivalent)**

If only a local stage exists without release, development may use `JUGNU_HELPER_PYTHON_RUNTIME` override / normal helper install path — document which path you used in the PR description.

---

### Task 2: Scaffold addon + router

**Files:**
- Create: `addons/clip-tools/addon.yaml` (minimal: 1–2 commands first, expand in later tasks)
- Create: `addons/clip-tools/bin/run`
- Create: `addons/clip-tools/app/__main__.py`
- Create: `addons/clip-tools/app/clipboard.py`
- Create: `addons/clip-tools/app/ops/__init__.py`
- Create: `addons/clip-tools/README.md`
- Create: `addons/clip-tools/tests/test_router.py`

**Interfaces:**
- Consumes: `JUGNU_HELPER_PYTHON_RUNTIME`
- Produces: router that maps `command` string → callable `(args, text) -> str` or error

- [x] **Step 1: Write failing router test**

```python
# tests/test_router.py — run with helper python
import json
import subprocess
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PY = Path(os.environ["JUGNU_HELPER_PYTHON_RUNTIME"]) / "bin" / "python3"

def run_cmd(command: str, clipboard: str, args=None):
    env = os.environ.copy()
    # Prefer injecting text via args for unit tests to avoid live pasteboard:
    payload = {"api": 1, "op": "run", "command": command, "args": {"_text": clipboard, **(args or {})}}
    proc = subprocess.run(
        [str(PY), "-I", str(ROOT / "app")],
        input=json.dumps(payload).encode(),
        capture_output=True,
        env={**env, "JUGNU_CLIP_TOOLS_INJECT": "1"},
    )
    return json.loads(proc.stdout.decode())

def test_unknown_command():
    out = run_cmd("nope", "hi")
    assert out["ok"] is False
    assert "unknown" in out["error"].lower() or "nope" in out["error"].lower()
```

Support `args._text` + `JUGNU_CLIP_TOOLS_INJECT=1` **only for tests** so CI does not need a pasteboard; production path uses real clipboard and ignores `_text` unless inject env is set.

- [x] **Step 2: Run test — expect fail**

```bash
export JUGNU_HELPER_PYTHON_RUNTIME="$(cd helpers/python-runtime && pwd)"
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I -m unittest addons.clip-tools.tests.test_router
```

Adjust module path / `cd addons/clip-tools && python -I -m unittest` as needed so imports work.

- [x] **Step 3: Implement bin/run, clipboard, __main__ dispatch**

`bin/run`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
py="${JUGNU_HELPER_PYTHON_RUNTIME:?python-runtime helper missing}/bin/python3"
exec "$py" -I "$root/app" "$@"
```

`__main__.py`: read stdin JSON; dispatch; print one JSON object; on success optionally write clipboard (skip write when inject mode returns only JSON for tests — or write only when not inject). Keep behavior explicit in code comments (one `//`-style `#` why if needed).

- [x] **Step 4: Re-run test — expect pass**

- [x] **Step 5: Minimal addon.yaml** with `helpers` and one probe command e.g. `clip-clear` or `text-stats`

- [x] **Step 6: Commit** (skip unless user asked)

---

### Task 3: Line + stats + case ops

**Files:**
- Create: `addons/clip-tools/app/ops/lines.py`, `stats.py`, `case.py`
- Modify: `app/__main__.py` dispatch table
- Modify: `addon.yaml` — add command entries
- Create: `tests/test_lines.py`, `test_stats.py`, `test_case.py`

**Commands:** `text-stats`, `case` (args.mode or separate ids per spec — prefer separate ids: `case-lower`, `case-upper`, `case-title`, `case-camel`, `case-snake`, `case-kebab` **or** one `case` with `args.style` — pick one approach and list every id in addon.yaml), `sort-lines`, `reverse-lines`, `dedupe-lines`, `trim-lines`, `number-lines`, `join-lines`, `split-lines`, `prefix-suffix`, `cut-field`

- [x] **Step 1: Write failing unit tests for pure functions** (no subprocess required)

Example:

```python
from app.ops.lines import dedupe_lines
assert dedupe_lines("a\nb\na\n") == "a\nb\n"
```

- [x] **Step 2: Implement ops; wire dispatch; update addon.yaml titles/keywords**

- [x] **Step 3: Run unit tests — pass**

- [x] **Step 4: Commit** (skip unless user asked)

---

### Task 4: JSON / CSV / XML / JSONPath

**Files:**
- Create: `app/ops/structured.py`
- Create: `tests/test_structured.py`
- Modify: dispatch + `addon.yaml`

**Commands:** `json-pretty`, `json-minify`, `csv-pretty`, `xml-pretty`, `csv-json`, `json-csv`, `xml-json`, `json-path`

- [x] **Step 1: Failing tests for pretty/minify and csv↔json round-trip**

- [x] **Step 2: Implement with stdlib `json`, `csv`, `xml.etree`**

- [x] **Step 3: Tests pass; invalid JSON returns ok:false plain error**

- [x] **Step 4: Commit** (skip unless user asked)

---

### Task 5: YAML (+ vendor if needed)

**Files:**
- Create: `app/vendor/` (vendored pure-Python YAML module — document source + license in `app/vendor/NOTICE`)
- Create/modify: structured YAML ops
- Create: `tests/test_yaml.py`

**Commands:** `yaml-pretty`, `yaml-json`, `json-yaml`

- [x] **Step 1: Vendor a known pure-Python YAML implementation (no pip at runtime)**

- [x] **Step 2: Tests + implement**

- [x] **Step 3: Commit** (skip unless user asked)

---

### Task 6: Encode / identity / misc

**Files:**
- Create: `app/ops/encode.py`, `identity.py`, `misc.py`
- Create: matching tests
- Modify: `addon.yaml` for remaining Phase 1 commands from the spec

**Commands:** `base64-encode`, `base64-decode`, `url-encode`, `url-decode`, `html-escape`, `html-unescape`, `jwt-decode`, `uuid`, `timestamp`, `iso-week`, `slugify`, `hash`, `tabs-spaces`, `invisible-chars`, `markdown-table`, `extract-emails`, `lorem`, `regex-replace`, `unicode-name`, `md-link`, `clip-clear`

- [x] **Step 1: Failing tests for base64, url, jwt header/payload decode (no verify), slugify, hash**

- [x] **Step 2: Implement; wire all remaining commands from spec §3**

- [x] **Step 3: Full unittest suite green**

- [x] **Step 4: Commit** (skip unless user asked)

---

### Task 7: Package validation + catalogs

**Files:**
- Modify: `docs/catalog-commands.md` (mark shipped command ids)
- Modify: `docs/catalog-ui.md` (Phase 1 toast-only note under Text Transform)
- Modify: `docs/backlog.md` if needed
- Modify: `CHANGELOG.md`
- Modify: `docs/tickets.md` (0061 → Done when complete)
- Optionally: `registry/addons.json` when publishing

- [x] **Step 1: validate-addon**

Run: `scripts/validate-addon.sh addons/clip-tools`  
Expected: pass

- [x] **Step 2: package-addon (local)**

Run: `scripts/package-addon.sh addons/clip-tools dist/`  
Expected: zip created

- [x] **Step 3: Manual palette smoke on a Mac** (after local install / `JUGNU_ADDON_PATH`): run `json-pretty` and `case-*` with real clipboard; confirm toast and clipboard contents

- [x] **Step 4: Update catalogs + CHANGELOG + ticket 0061**

- [x] **Step 5: Commit** (skip unless user asked)

---

## Spec coverage check

| Spec requirement | Task |
|---|---|
| One zip, many commands | 2–6 |
| Declares python-runtime helper; no in-zip CPython | 2 |
| Phase 1 command families | 3–6 |
| Oneshot, clipboard I/O, plain errors | 2 |
| YAML via app/vendor | 5 |
| No Phase 2 UI | explicit non-goal |
| Catalogs / validate / package | 7 |

## Out of scope (do not implement here)

Text Transform `canvas`, `diff`, paste-plain merge, publishing Release unless asked.
