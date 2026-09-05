# Addon install & upgrade integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a single trusted install pipeline for addons and helpers (required sha256, ZIPFoundation entry-validated extract, atomic stage/commit, cancel/crash recovery), then layer package gates, catalog dependencies, upgrade UI, and namespaced-id migration on top — finishing each phase before starting the next.

**Architecture:** Split today’s `AddonInstaller` monolith into focused Core types: allowlisted download session, `ZipExtractor` (ZIPFoundation), `AtomicCommit`, package gates, dependency transaction, namespace migrator. App owns replace-under-running prompts via `AddonProcessHost`. Helpers use the same stage→commit path as addons. No second installer for upgrades or deps.

**Tech Stack:** Swift / JugnuCore + App, ZIPFoundation (SPM), XCTest fixtures (crafted zips), `scripts/validate-addon.sh`, existing `UserFacingError` / catalog UI.

**Spec:** [docs/architecture/2026-09-05-addon-install-upgrade-integrity-design.md](../../architecture/2026-09-05-addon-install-upgrade-integrity-design.md)

## Global Constraints

- **Git:** do not run git, do not branch, do not commit (`AGENTS.md`). Skip every “Commit” instinct; mark steps done after tests pass. Leave the working tree for the user.
- **Every phase ships green and is independently shippable.** End each phase with `cd shell && swift test` green. Touch `validate-addon.sh` only when the phase requires it; then run it on a representative addon.
- **Honor the locked tables in the spec.** Do not relitigate ZIPFoundation, host allowlist, exact SemVer deps, L2 single live dir, or resumable per-item namespace migration.
- **Layering:** download / extract / commit / gates / resolver stay in **JugnuCore**. Replace-under-running **prompt** wiring lives in **App** (needs `AddonProcessHost`). No AppKit in Core.
- **Errors:** every new `AddonInstallerError` (and related) case that can reach the user gets a `UserFacingError.message(for:)` arm before the phase is Done.
- **Not this plan:** signing, L3 side-by-side versions, sandbox (0021), bundles (0048), app self-update (0017), `JUGNU_ADDON_PATH` banner (0035), `session` IPC (0059).

---

## File map

| Path | Phase | Responsibility |
|---|---|---|
| `shell/Package.swift`, `shell/project.yml`, `Package.resolved` | 1 | Add ZIPFoundation → JugnuCore |
| `shell/Sources/JugnuCore/Install/InstallHostAllowlist.swift` | 1 | Allowed download hosts |
| `shell/Sources/JugnuCore/Install/AllowlistedURLSession.swift` | 1 | `URLSession` + redirect cancel |
| `shell/Sources/JugnuCore/Install/ZipExtractor.swift` | 1 | ZIPFoundation extract + path policy + caps |
| `shell/Sources/JugnuCore/Install/AtomicCommit.swift` | 2 | stage → trash → rename → cleanup |
| `shell/Sources/JugnuCore/Install/PackageGates.swift` | 3 | `minShellVersion`, Mach-O/`#!` check |
| `shell/Sources/JugnuCore/Install/DependencyResolver.swift` | 4 | topo, cycles, exact version, collisions |
| `shell/Sources/JugnuCore/Install/InstallTransaction.swift` | 4 | multi-package stage/commit/rollback |
| `shell/Sources/JugnuCore/Install/NamespaceMigrator.swift` | 6 | per-item resumable migrate |
| `shell/Sources/JugnuCore/Paths.swift` | 1–2 | `.staging` / `.trash` helpers |
| `shell/Sources/JugnuCore/AddonInstaller.swift` | 1–5 | Orchestrate pipeline; kill unzip + sha skip |
| `shell/Sources/JugnuCore/ManifestLoader.swift` (+ models) | 3–4, 6 | `minShellVersion`, `dependencies`, namespaced id rules |
| `shell/Sources/JugnuCore/UserFacingError.swift` | 1–6 | All new error copy |
| `shell/App/…` (catalog / AppModel) | 2, 4, 5 | Replace prompt; dep disclosure; Update badge/action |
| `scripts/validate-addon.sh` | 3, 6 | Gates + id/reserved-name rules |
| `docs/addon-manifest.md` | 3–6 | New fields |
| `docs/tickets.md`, `CHANGELOG.md` | each | Status as phases land |

---

## Phase 1 — Trust + extract (no atomic commit yet)

**Ships:** required sha256 (both former skip sites), allowlisted download session, ZIPFoundation extract with zip-slip guards. Install may still use a transitional promote into live **only if** extract is safe; prefer landing AtomicCommit in phase 2 immediately after — if phase 1 still copies to live, document it as temporary and do not expand that path.

### 1.1 Add ZIPFoundation

- [x] **Step 1:** Add to `shell/Package.swift`:
- [x] **Step 2:** `cd shell && swift test` still green (dependency only).

### 1.2 Allowlist + download session

- [x] **Step 1:** Lock hosts: `github.com`, `objects.githubusercontent.com`. Reject non-https and `file://`.
- [x] **Step 2:** Implement session whose redirect delegate cancels when host leaves the allowlist.
- [x] **Step 3:** Unit-test allowlist policy.
- [x] **Step 4:** Replace `URLSession.shared.download` in `AddonInstaller.install` and helper fetch.

### 1.3 ZipExtractor

- [x] **Step 1:** Failing tests for `../`, absolute paths.
- [x] **Step 2:** Implement extract-to-directory using ZIPFoundation with caps.
- [x] **Step 3:** Resolve package root.
- [x] **Step 4:** Delete `/usr/bin/unzip` private method from `AddonInstaller`.

### 1.4 Require sha256

- [x] **Step 1:** Test: nil or `""` → throw (addon + helper).
- [x] **Step 2:** Remove skip branches.
- [x] **Step 3:** Map new errors in `UserFacingError`.
- [x] **Step 4:** `cd shell && swift test` green. Phase 1 Done.

---

## Phase 2 — Atomic commit + replace-under-running + local stage path

### 2.1 Paths + AtomicCommit

**Files:** `Paths.swift`, create `AtomicCommit.swift`; Test: `AtomicCommitTests.swift`

- [x] **Step 1:** Add helpers, e.g. `addonsStagingDir`, `addonsTrashDir`, `helpersStagingDir`, `helpersTrashDir`. Never treat `.staging`/`.trash` as package ids.

- [x] **Step 2:** API sketch:

```swift
public enum AtomicCommit {
    public static func promote(staging: URL, live: URL, trashParent: URL) throws
}
```

Behavior: if `live` exists → rename to `trashParent/<name>-<uuid>`; rename `staging` → `live`; delete trash entry. On failure after live moved aside, attempt to rename trash back to `live`.

- [x] **Step 3:** Tests: fresh install; replace; simulated failure leaves previous live (inject by making dest non-writable only if reliable — otherwise test trash restore helper).

### 2.2 Wire AddonInstaller (addons + helpers)

- [x] **Step 1:** Zip path: extract into staging under `.staging/…`, gates stub (no-op until phase 3), `AtomicCommit.promote`.

- [x] **Step 2:** Helpers: same stage+commit into `helperRoot`; **no** live `copyItem` without staging.

- [x] **Step 3:** `installFromDirectory`: copy tree into staging, then promote (skip hash/extract).

- [x] **Step 4:** Launch recovery: on app start (AppDelegate or existing startup path), delete orphaned `.staging/**`; delete `.trash/**` older than one successful promote (or delete immediately after successful promote in `AtomicCommit`).

- [x] **Step 5:** Tests from spec §10 phase 2 (crash mid-stage = leave staging then recovery wipe; cancel cleans staging — cancel may be App-level; Core can expose `InstallWork` cleanup).

### 2.3 Replace-under-running (App)

- [x] **Step 1:** Before any addon promote that would replace an existing live id, App checks `AddonProcessHost.hasTracked` for that addon. If true: alert accept→`killTracked` then proceed; reject→abort.

- [x] **Step 2:** Cover reinstall and upgrade entry points (phase 5 will reuse).

- [x] **Step 3:** App or Core test with host stub if feasible; else document manual smoke and add a unit test for the decision helper.

- [x] **Step 4:** `swift test` green. Phase 2 Done.

---

## Phase 3 — Package gates

### 3.1 Manifest: `minShellVersion`

- [x] **Step 1:** Parse optional `minShellVersion` on `AddonManifest`. Reject invalid SemVer at load.

- [x] **Step 2:** `PackageGates.checkMinShellVersion(required:running:)` — SemVer compare.

- [x] **Step 3:** Call at install (before commit). Call at **load/index** time: if installed addon fails gate → mark not runnable / skip invoke with plain copy (do not uninstall).

- [x] **Step 4:** Tests: install blocked; load-time skip without deleting tree.

### 3.2 Universal / script entrypoint

- [x] **Step 1:** If `exec` and file starts with `#!` → pass. If Mach-O → require `arm64` and `x86_64` via `lipo`/mach-o headers. Else fail.

- [x] **Step 2:** Mirror in `validate-addon.sh` with the same branch (no `lipo` on scripts).

- [x] **Step 3:** Reject leading-dot / `.staging` / `.trash` ids in validator + manifest id validation.

- [x] **Step 4:** `UserFacingError` arms; `docs/addon-manifest.md` updated; `swift test` + `validate-addon.sh addons/paste-plain` (or similar) green. Phase 3 Done.

---

## Phase 4 — Catalog dependencies

### 4.1 Manifest `dependencies`

```yaml
dependencies:
  - id: jugnu.other   # post-phase-6 shape; pre-6 use current ids in fixtures
    version: 1.0.0
```

- [x] **Step 1:** Parse list; exact SemVer; no ranges.

- [x] **Step 2:** `DependencyResolver.plan(root:registry:installed:)` → topo order or errors: cycle, unknown, versionMismatch, collision.

### 4.2 Disclosure + transaction

- [x] **Step 1:** Catalog Install flow: present confirm listing already installed vs will install; note installed ≠ enabled.

- [x] **Step 2:** `InstallTransaction`: stage all missing addons + helpers; commit helpers then addons; track created ids; rollback created only on failure.

- [x] **Step 3:** Newly installed deps → `enabled: false`; primary enable flag only for clicked addon.

- [x] **Step 4:** Tests: topo, cycle, exact mismatch refuse, rollback removes created helper+addon, collision refuse.

- [x] **Step 5:** `UserFacingError` + manifest docs; `swift test` green. Phase 4 Done.

---

## Phase 5 — Upgrade UI (0018)

- [x] **Step 1:** Compare installed vs registry SemVer; expose `updateAvailable` on catalog view model.

- [x] **Step 2:** Update button → dep disclosure if needed → pipeline replace (uses §3.4 running-process policy).

- [x] **Step 3:** Preserve enabled flag and `state/<id>/`.

- [x] **Step 4:** Tests: badge true/false; failure keeps old tree; enable unchanged.

- [x] **Step 5:** `swift test` green. Phase 5 Done. Mark ticket 0018 Done in remarks when landing.

---

## Phase 6 — Namespaced ids (0031)

### 6.1 Data rewrite

- [x] **Step 1:** Rename all first-party `addon.yaml` ids and `registry/addons.json` to `jugnu.<job>`. Update `dependencies` fixtures, docs, catalogs, tests, `ShellConfig.recommendedAddonIDs`, daemon allowlists, etc. Grep for bare ids.

- [x] **Step 2:** Id validation: `<publisher>.<job>` for catalog addons; helpers stay un-namespaced.

### 6.2 NamespaceMigrator

- [x] **Step 1:** On launch, for each `addons/<job>/` without a dot: migrate that id (dir rename + config key + state dir) as one unit; persist progress; continue next launch if interrupted.

- [x] **Step 2:** Marker when no un-prefixed addon dirs remain.

- [x] **Step 3:** Remap recents/favorites best-effort.

- [x] **Step 4:** Tests: mid-pass crash resume; collision refuse; remapped recents.

- [x] **Step 5:** Docs + tickets 0031/0058 Done criteria; CHANGELOG; `swift test` green. Phase 6 / epic Done.

---

## Docs checklist (fold into the phase that introduces the field)

- [ ] `docs/addon-manifest.md` — `minShellVersion`, `dependencies`, namespaced `id`, reserved names
- [ ] `docs/architecture/README.md` — link plan; status Approved when implementing
- [ ] `docs/tickets.md` — 0018/0025/0029/0031/0043/0058 remarks as phases complete
- [ ] `CHANGELOG.md` — one line per phase ship (or one epic summary at end — prefer per phase)
- [ ] `docs/architecture/shell-smoke.md` — manual: install, cancel, replace-under-running, dep disclosure, update, namespaced install

---

## Spec coverage self-check

| Spec section | Plan phase |
|---|---|
| §3.0 local installs | 2.2 |
| §3.1 trust + redirect session + both sha skips | 1.2, 1.4 |
| §3.2 ZIPFoundation extract | 1.1, 1.3 |
| §3.3 reserved `.staging`/`.trash` | 2.1, 3.3 |
| §3.4 atomic commit + replace-under-running | 2.1–2.3 |
| §3.5 launch recovery | 2.2 |
| §4.1 minShellVersion install+load | 3.1 |
| §4.2 Mach-O / `#!` | 3.2 |
| §5 deps + helpers in transaction | 4 |
| §6 upgrade UI | 5 |
| §7 namespaces + resumable migrate | 6 |
| §9 UserFacingError | each phase |
| §11 Done criteria | end of phase 6 |

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-05-addon-install-upgrade-integrity.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task/phase slice, review between tasks  
2. **Inline Execution** — execute in this session with executing-plans checkpoints  

Which approach?
