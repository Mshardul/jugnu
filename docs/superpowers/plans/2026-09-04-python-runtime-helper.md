# `python-runtime` helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship first-party helper `python-runtime` — a pinned standalone CPython on macOS — so addons can run Python without a user-installed interpreter.

**Architecture:** Follow the existing helper contract ([addon-manifest Helpers](../../addon-manifest.md#helpers)): `helper.yaml` + zip published via GitHub Releases, listed in `registry/helpers.json`. Fetch a pinned python-build-standalone (or equivalent) build, stage `bin/python3`, package like `scripts/package-helper-clock.sh`. No shell Core changes unless env wiring is broken. No catalog addon in this plan.

**Tech Stack:** bash packaging scripts, standalone CPython, existing Jugnu helper install path, sha256 registry row.

**Spec:** [docs/architecture/2026-09-04-python-runtime-helper-design.md](../../architecture/2026-09-04-python-runtime-helper-design.md)

## Global Constraints

- Helper id `python-runtime`, version `1.0.0`; not a catalog product; no enable key.
- Stdlib only inside the helper; no pip on the user machine; no runtime network from the helper.
- Must run on Apple Silicon and Intel (universal or dual-arch entry that works on both).
- Do not implement `clip-tools` in this plan — that is [2026-09-04-clip-tools](./2026-09-04-clip-tools.md).
- **Git:** do not create commits unless the user explicitly asked for commits in the session (repo `AGENTS.md`). Skip every “Commit” step below when commits were not requested; still mark the step done after verifying checks.
- Do not run `gh release` / registry publish writes unless the user explicitly asked.

---

## File map

| Path | Responsibility |
|---|---|
| `helpers/python-runtime/helper.yaml` | `id` + `version` |
| `helpers/python-runtime/README.md` | What this helper is / is not; how addons invoke it |
| `helpers/python-runtime/lock.json` | Pinned download URL(s) + sha256 (+ arch notes) |
| `scripts/fetch-python-runtime.sh` | Download, verify, stage tree under `helpers/python-runtime/` |
| `scripts/package-helper-python-runtime.sh` | Stage `helper.yaml` + runtime → zip; print sha256 |
| `registry/helpers.json` | New row after pack (url + sha256) |
| `docs/tickets.md` | Ticket for this helper (and pointer to clip-tools follow-on) |
| `docs/architecture/README.md` | Link this spec |
| `docs/catalog-commands.md` / backlog | Short pointer: Python addons need this helper first |
| `CHANGELOG.md` | Documentation / Added helper note when shipped |

---

### Task 1: Spec status, tickets, doc pointers

**Files:**
- Modify: `docs/architecture/2026-09-04-python-runtime-helper-design.md` (Status → Approved once user approved; otherwise leave Draft until then)
- Modify: `docs/tickets.md`
- Modify: `docs/architecture/README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: draft spec
- Produces: ticket id **0060** (python-runtime helper), **0061** (clip-tools Phase 1 — Not started, depends on 0060)

- [x] **Step 1: Append tickets**

Match existing `docs/tickets.md` columns. Suggested rows:

| 0060 | `python-runtime` helper | Pinned standalone CPython helper (not catalog). Spec: [2026-09-04 python-runtime](architecture/2026-09-04-python-runtime-helper-design.md). Plan: [2026-09-04-python-runtime-helper](superpowers/plans/2026-09-04-python-runtime-helper.md). First consumer: clip-tools (0061). | High | M | 0047 | Not started | 2026-09-04 | 2026-09-04 | Implement before clip-tools. |
| 0061 | `clip-tools` Phase 1 | Clipboard text transform commands; declares `python-runtime`. Spec: [2026-09-04 clip-tools](architecture/2026-09-04-clip-tools-design.md). Plan: [2026-09-04-clip-tools](superpowers/plans/2026-09-04-clip-tools.md). No Transform UI (Phase 2 later). | High | L | 0060 | Not started | 2026-09-04 | 2026-09-04 | Helper-first sequencing. |

- [x] **Step 2: Link specs from architecture README**

Add two rows to the status table in `docs/architecture/README.md` pointing at the python-runtime and clip-tools specs/plans.

- [x] **Step 3: CHANGELOG documentation bullet**

`- 2026-09-04 — Drafted python-runtime helper + clip-tools designs and plans (helper first).`

- [x] **Step 4: Commit** (skip unless user asked)

---

### Task 2: Helper manifest + lock skeleton

**Files:**
- Create: `helpers/python-runtime/helper.yaml`
- Create: `helpers/python-runtime/README.md`
- Create: `helpers/python-runtime/lock.json`
- Create: `helpers/python-runtime/.gitignore` (ignore staged interpreter tree if not committed)

**Interfaces:**
- Produces: `helper.yaml` with `id: python-runtime`, `version: 1.0.0`

- [x] **Step 1: Write helper.yaml**

```yaml
id: python-runtime
version: 1.0.0
```

- [x] **Step 2: Write README**

State: interpreter only; consumers use `$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3`; stdlib only; clip-tools is first consumer; not a catalog product.

- [x] **Step 3: Write lock.json skeleton**

```json
{
  "version": "1.0.0",
  "cpython": "3.12.x",
  "source": "python-build-standalone",
  "artifacts": [
    {
      "arch": "aarch64-apple-darwin",
      "url": "REPLACE_WITH_PINNED_URL",
      "sha256": "REPLACE"
    },
    {
      "arch": "x86_64-apple-darwin",
      "url": "REPLACE_WITH_PINNED_URL",
      "sha256": "REPLACE"
    }
  ],
  "notes": "Prefer one install layout that exposes helpers/python-runtime/bin/python3 on both archs (lipo, arch-specific subdirs + wrapper, or single universal build if available)."
}
```

Pin real URL/sha256 in Task 3 after choosing the exact release.

- [x] **Step 4: Commit** (skip unless user asked)

---

### Task 3: Fetch script + pin real artifacts

**Files:**
- Create: `scripts/fetch-python-runtime.sh`
- Modify: `helpers/python-runtime/lock.json` (real pins)
- Modify: `helpers/python-runtime/.gitignore`

**Interfaces:**
- Produces: staged tree with executable `helpers/python-runtime/bin/python3`

- [x] **Step 1: Choose and pin CPython build**

Look up current python-build-standalone release assets for macOS aarch64 + x86_64 (install-only / compatible flavor). Write exact URLs and sha256 into `lock.json`. Record chosen CPython version in README.

- [x] **Step 2: Implement fetch-python-runtime.sh**

Requirements:

- `set -euo pipefail`
- Read `lock.json` (python3 or jq — if using python3 for JSON, use system python **only on the developer machine** for this script, or parse with enough bash; prefer `python3` on dev or `jq` if already in repo scripts)
- Download to a temp dir; `shasum -a 256` verify; fail on mismatch
- Extract and normalize so `helpers/python-runtime/bin/python3` exists and is executable
- For dual-arch: either produce a wrapper script at `bin/python3` that execs the correct arch subtree, or document lipo steps — pick one and implement it fully
- Idempotent: re-run skips download if sha matches existing stage marker file

- [x] **Step 3: Run fetch locally**

Run: `scripts/fetch-python-runtime.sh`  
Expected: `helpers/python-runtime/bin/python3` exists.

- [x] **Step 4: Smoke the interpreter**

Run:

```bash
helpers/python-runtime/bin/python3 -I -c 'import sys, json; print(json.dumps({"ok": True, "version": sys.version}))'
```

Expected: JSON with `"ok": true` and a 3.12+ version string. No use of `/usr/bin/python3` for this check.

- [x] **Step 5: Commit** (skip unless user asked) — do **not** commit huge binary trees if `.gitignore` excludes them; commit lock + scripts + helper.yaml + README

---

### Task 4: Package script

**Files:**
- Create: `scripts/package-helper-python-runtime.sh`

**Interfaces:**
- Consumes: staged `helpers/python-runtime/` with `helper.yaml` + `bin/python3` (+ tree)
- Produces: `dist/python-runtime-1.0.0.zip` and prints sha256 to stdout (mirror clock script)

- [x] **Step 1: Write package-helper-python-runtime.sh**

Mirror structure of `scripts/package-helper-clock.sh`:

- Parse id/version from `helper.yaml`
- Require `bin/python3` present (run fetch first if missing)
- Stage into `dist/python-runtime-1.0.0/` including everything needed to run offline
- `zip -qr` the staging dir
- Print sha256 to stdout; zip path to stderr

- [x] **Step 2: Run package script**

Run: `scripts/package-helper-python-runtime.sh`  
Expected: zip path on stderr; 64-char sha256 on stdout.

- [x] **Step 3: Commit script** (skip unless user asked)

---

### Task 5: Registry row + local install smoke

**Files:**
- Modify: `registry/helpers.json`
- Modify: `registry/README.md` (one line example that helpers include `clock` and `python-runtime`)

**Interfaces:**
- Produces: helpers.json entry ready for release URL (may use placeholder Release URL until user publishes; sha256 from Task 4)

- [x] **Step 1: Add helpers.json entry**

```json
{
  "id": "python-runtime",
  "version": "1.0.0",
  "url": "https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0/python-runtime-1.0.0.zip",
  "sha256": "<sha from package script>"
}
```

Keep existing `clock` entry. Do not publish the GitHub Release in this task unless the user asked.

- [x] **Step 2: Local helper path smoke (dev)**

Simulate consumer env:

```bash
export JUGNU_HELPER_PYTHON_RUNTIME="$(cd helpers/python-runtime && pwd)"
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I -c 'print(1+1)'
```

Expected: `2`

- [x] **Step 3: CHANGELOG Added bullet when helper is actually releasable**

`- 2026-09-04 — Shared python-runtime helper: pinned standalone CPython for first-party addons.`

- [x] **Step 4: Mark ticket 0060 Done** in `docs/tickets.md` with link to spec + plan when packaging + registry row are in place.

- [x] **Step 5: Commit** (skip unless user asked)

---

## Spec coverage check

| Spec requirement | Task |
|---|---|
| Helper id/version, not catalog | 1–2 |
| Pinned standalone CPython, arch support | 3 |
| `bin/python3` entry | 3–4 |
| Package zip + sha256 registry | 4–5 |
| Stdlib only / no pip / no clip-tools logic | 2 README + out of scope |
| Offline / last-consumer | existing 0047 — verify only |
| Implement before clip-tools | plan order + ticket 0061 depends on 0060 |

## Placeholder scan

None intentional. `REPLACE_WITH_PINNED_URL` in Task 2 is replaced in Task 3 before fetch is considered done.
