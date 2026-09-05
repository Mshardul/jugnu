# Jugnu — addon install & upgrade integrity

**Date:** 2026-09-05  
**Status:** Approved  
**Plan:** [2026-09-05-addon-install-upgrade-integrity](../superpowers/plans/2026-09-05-addon-install-upgrade-integrity.md)  

**Epic:** [ticket 0058](../tickets.md)  
**Absorbs (when phases Done):** [0018](../tickets.md) upgrade-in-place · [0025](../tickets.md) catalog dependencies · [0029](../tickets.md) universal binary · [0031](../tickets.md) namespaced ids · [0043](../tickets.md) `minShellVersion`  
**Depends on:** [Shell design](./2026-08-22-shell-design.md), [Addon manifest](../addon-manifest.md), [Helpers](../addon-manifest.md#helpers) ([0047](../tickets.md)), [Catalog browse](./2026-08-23-addon-catalog-browse-design.md), [Addon process lifecycle](./2026-08-30-addon-process-lifecycle-design.md) (running-process policy on replace), [Release process](../release-process.md), `JugnuPaths.helperRoot(id:version:)` ([Paths.swift](../../shell/Sources/JugnuCore/Paths.swift))  
**Not this spec:** code signing / notarization / Sparkle · side-by-side `addons/<id>/<version>/` (L3) · per-addon sandbox ([0021](../tickets.md)) · catalog bundles ([0048](../tickets.md)) · app self-update ([0017](../tickets.md)) · addon→addon runtime IPC ([ideas.md](../ideas.md)) · visible `JUGNU_ADDON_PATH` banner ([0035](../tickets.md); trust posture for local installs is stated here, UI chrome is not)

## 0. Purpose

Getting bytes onto disk safely is one concern. Today it is scattered: `AddonInstaller` sha256-checks and unpacks to a temp dir before copy, but `/usr/bin/unzip` has **no zip-slip / symlink guard**, the final live replace is not crash-atomic, empty sha256 **skips verification** at both zip and helper call sites (`installFromLocalZip` / `installHelperFromLocalZip`), and follow-on product needs (upgrade UI, catalog deps, install gates, namespaced ids) have no single pipeline to stand on.

This epic makes the shell a **long-lived trusted installer**: one pipeline for addons and helpers, phased product layers on top, and explicit seams for signing and side-by-side versions later — without building those futures in 0058.

**Long-term posture (locked):** implement **L2** now (owned extract + atomic commit + sha256 trust), with **seams** toward signing and **L3** (content-addressed / side-by-side versions). Do not ship L1 (“harden unzip and hope”) as the foundation.

## 1. Goals and non-goals

### Goals

- One install pipeline for **addons and helpers**: trust → entry-validated extract → verify → atomic commit.
- Crash or cancel never leaves a half-tree in the live install root.
- Phases 3–6 build only on that pipeline (no second installer).
- Spec documents seams for later signing and L3 without implementing them.
- When a phase starts, it finishes (no “format lock only / migrate someday” for work in scope).

### Non-goals (0058)

- Code signing, notarization, Sparkle
- Side-by-side `addons/<id>/<version>/` live layout (L3)
- Per-addon sandboxing (0021)
- Bundles (0048)
- Changing the helper *product* model (still not catalog; still `helpers/<id>/<version>/` via `helperRoot`)
- `JUGNU_ADDON_PATH` visibility banner (0035)

## 2. Phase map

Finish each phase before starting the next.

| Phase | Delivers | Absorbs |
|---|---|---|
| 1 | Safe extract + trust gates (required sha256, host policy, download session) | zip-slip security-audit seed |
| 2 | Atomic stage/commit + cancel/crash recovery + replace-under-running policy | cancelled-install integrity |
| 3 | `minShellVersion` (install + load) + universal-binary checks | 0043, 0029 |
| 4 | Catalog `dependencies` + ordered install + rollback (addons **and** helpers) | 0025 |
| 5 | Update-available UI + user-triggered update | 0018 |
| 6 | Namespaced ids + resumable per-item migration | 0031 |

## 3. Core pipeline (phases 1–2)

Network installs and local unpacked installs share **gates + atomic commit**. Trust + extract apply only to zip downloads.

```
# Registry / helper zip
download (allowlisted session) → require sha256 → extract into stage (entry-validated)
  → load manifest → package gates → atomic commit → enable/config

# Local unpacked (dev / first-run / JUGNU_ADDON_PATH materialization into live tree)
copy/source tree into stage → load manifest → package gates → atomic commit → enable/config
```

### 3.0 Local unpacked installs

| Topic | Decision |
|---|---|
| Paths | `installFromDirectory` and materializing from `JUGNU_ADDON_PATH` remain after 0058. |
| Skip | Network trust (sha256, host allowlist) and zip extract — source is already a directory. |
| Still run | Package gates (phase 3+) and **atomic commit** into the live root (stage copy → rename). Do not `removeItem`+`copyItem` live in place. |
| Trust posture | Developer / first-party override — not registry-verified. Visibility of the env override is ticket 0035, not this epic. |
| Namespaces | After phase 6, local manifests must use namespaced ids (see §7.2). |

### 3.1 Trust (phase 1) — network zips only

| Topic | Decision |
|---|---|
| sha256 | Registry / helper catalog entries **must** have non-empty `sha256`. Empty or nil → hard fail. **Both** current skip sites (`installFromLocalZip` and `installHelperFromLocalZip`) lose the skip path. |
| When | Hash verified on zip bytes **before** any extract. |
| Transport | `https` only. Reject `file://` for download URLs. |
| Host allowlist (v0) | `github.com`, `objects.githubusercontent.com` (extend only by explicit list change). |
| Redirects | **Mechanism required:** do not use `URLSession.shared` for registry/helper downloads. Use a dedicated `URLSession` whose delegate implements `urlSession(_:task:willPerformHTTPRedirection:…)` (or equivalent) and **cancels** any hop whose host leaves the allowlist. Transparent follow-then-hope is insufficient. |
| Signing seam | Optional signature verify may sit beside/after hash, still **before** extract; same pipeline. |

### 3.2 Extract (phase 1)

| Topic | Decision |
|---|---|
| Library | **ZIPFoundation**, linked from **JugnuCore** (concrete need; Foundation has no public zip API). Do not hand-roll over Compression. Do not shell `/usr/bin/unzip` for untrusted packages. |
| Per entry (before write) | Reject absolute paths, `..`, backslash escapes, symlinks, and non-regular files that could escape the stage. |
| Caps | Max entry count + max uncompressed total (Core constants). Fail closed. |
| Package root | `addon.yaml` / `helper.yaml` at extract root **or** exactly one child directory that contains it (current layouts). Ambiguous multi-root → fail. |

### 3.3 Stage locations

| Kind | Stage | Live (L2) |
|---|---|---|
| Addon | `~/.local/share/jugnu/addons/.staging/<id>-<uuid>/` | `addons/<id>/` |
| Helper | `~/.local/share/jugnu/helpers/.staging/<id>-<version>-<uuid>/` | `helpers/<id>/<version>/` (= `JugnuPaths.helperRoot`) |

| Topic | Decision |
|---|---|
| Reserved dir names | Under `addons/` and `helpers/`, **`.staging` and `.trash` are reserved**. Never treat them as installable addon/helper ids. |
| Addon id shape | Manifest / `validate-addon.sh`: reject ids that are empty, start with `.`, or equal reserved names. Leading-dot ids are invalid. |
| Loader | Never enumerate `.staging` / `.trash` as installed packages. |

### 3.4 Atomic commit (phase 2)

Applies to **addons and helpers**.

| Topic | Decision |
|---|---|
| Success path | Fully write under staging → `rename` staging → live dest. |
| Replace existing | Rename live → `.trash/<…>-<uuid>/`, rename staging → dest, then delete trash. Never delete live before staging is ready to promote. |
| Failure mid-swap | Prefer leaving the previous live tree intact. |
| Cancel / throw / death | Delete staging; do not touch live (except launch recovery of orphans). |
| Browse cancel | View-owned install `Task` cancel aborts download/extract/stage and cleans staging. No partial live tree. |
| **Replace under running processes** | Any commit that would replace a live **addon** tree while `AddonProcessHost` has tracked work for that addon id (reinstall, upgrade, dep re-stage, local re-commit): **same policy as disable-with-open-panel / 0057** — accept → kill then commit; reject → abort with live tree unchanged. This is a **phase 2** rule, not only a phase 5 Update UI rule. Helpers have no process host entries. |

### 3.5 Launch recovery

On startup:

- Delete orphaned `addons/.staging/**` and `helpers/.staging/**`.
- Delete aged `addons/.trash/**` and `helpers/.trash/**` (bounded: remove after successful commit, or on a later launch).

## 4. Package gates (phase 3)

Run **after** manifest load, **before** atomic commit, on the staging tree (network and local). Mirror the same checks in `scripts/validate-addon.sh`.

### 4.1 `minShellVersion` (0043)

| Topic | Decision |
|---|---|
| Field | Optional SemVer on `addon.yaml`, e.g. `minShellVersion: 0.2.0`. |
| vs `api:` | `api:` = protocol major; `minShellVersion` = shell *internals* floor. Separate axes. |
| Compare to | Running app marketing version (`CFBundleShortVersionString`). |
| **Install** | If present and shell &lt; required → hard fail; plain copy; nothing committed. |
| **Load (downgrade)** | If an already-installed addon’s `minShellVersion` exceeds the running shell → treat as **not runnable** (do not invoke; plain reason in UI/logs as appropriate). **Do not uninstall** or delete the tree. User upgrades the shell or disables the addon themselves. |
| Omit | No floor (current behavior). |
| Helpers | No `minShellVersion` in v0 (first-party-pinned). |

### 4.2 Universal binary (0029)

| Topic | Decision |
|---|---|
| When | `entrypoint.kind: exec` only. |
| Rule | If the entrypoint file is **Mach-O**, it must be universal with **both** `arm64` and `x86_64`. If it begins with `#!` (script), **pass** without `lipo`. |
| Skip | `jxa` / `osascript` entrypoints. |
| Helpers | Do not force a single fat binary at helper zip root. Dual `arch/` layouts (e.g. `python-runtime`) remain valid; addon `exec` entrypoints are the packaging gate. |
| Failure | Hard fail; plain copy; nothing committed. |
| Validator | Same branching logic in `validate-addon.sh` — never run `lipo -archs` on a text script. |

## 5. Catalog dependencies (phase 4 / 0025)

### 5.1 Manifest

```yaml
dependencies:
  - id: some-addon    # catalog addon id (namespaced after phase 6)
    version: 1.0.0    # exact SemVer in v0 — no ranges
```

| Topic | Decision |
|---|---|
| vs helpers | Distinct from `helpers:` (0047). Helpers stay non-catalog, auto-fetched, no enable key. |
| Omit | Allowed when none. |
| Cycles | Hard fail at plan time. |
| Unknown id | Hard fail before any download. |
| **Exact version vs installed** | At L2 there is one live dir per addon id. If a dependency requires exact `1.0.0` and the user already has `1.1.0` (or any other version) installed → **refuse** the transaction (plain copy). No silent downgrade; no coexist. L3 seam later may allow side-by-side. |
| **Publisher collision** | If resolving a dependency targets an id already occupied under collision rules (§7.1) → fail the transaction before staging (same refuse as a direct install). |

### 5.2 Disclosure UX

Before bytes move, show confirm:

- Target addon name
- Each dependency: **already installed** / **will be installed now**
- Explicit note: installed ≠ enabled; user enables each addon themselves (vision rule 4)

Accept → transaction. Reject → no changes.

### 5.3 Transaction

1. Resolve closure; topo order (dependencies first, then the requested addon). Apply exact-version and collision checks (§5.1) before any download.
2. Stage all missing **addons** via the core pipeline (gates included). Do not commit yet.
3. Stage all missing **helpers** declared by any package in the set via the **same** stage→gates→(pending commit) path — **not** live-write `installHelperFromLocalZip` as today.
4. Commit helpers, then addons, in a recorded order. Track **transaction-created** addon ids **and** helper `(id, version)` pairs.
5. Config: newly installed dependency addon ids get `enabled: false`. The primary addon’s `enable` flag follows the caller’s intent **only for the addon the user clicked**.
6. On failure or cancel: rollback — remove only transaction-created addon dirs **and** transaction-created helper versions; never remove pre-existing installs; wipe all staging for the transaction.

Replace-under-running (§3.4) applies to any addon commit in this transaction that would replace a live tree with tracked processes.

### 5.4 Uninstall and runtime

| Topic | Decision |
|---|---|
| Uninstall A | Does **not** auto-uninstall dependencies (catalog products). “Also remove unused deps” is out of 0058. |
| Helpers | Last-consumer cleanup unchanged for helpers **not** created solely to be rolled back mid-transaction. |
| Runtime IPC | Not in scope (ideas.md). Dependencies are install-time only. |
| Enable A while dep disabled | Allowed; do not auto-enable the dependency. |

## 6. Upgrade in place (phase 5 / 0018)

Discover → disclose → **same** pipeline (not a second updater).

| Topic | Decision |
|---|---|
| Detection | Installed `addon.yaml` `version` vs registry `version` (SemVer). Registry newer → update available. |
| Auto | Never. Manual **Update** on catalog card/detail only. |
| Helpers | No catalog update UI. New helper pin on upgraded addon → ensure via staged helper commit; old helper version may drop via last-consumer cleanup. |
| Deps on update | If the new version needs new dependencies, reuse phase 4 disclosure (including exact-version refuse). |
| Enable | Upgrade does not change enabled/disabled. |
| State / config | `state/<id>/` and per-addon config survive upgrade. |
| Running processes | Covered by §3.4 replace-under-running (Update is one caller of that policy). |
| Failure | Previous version remains live; staging deleted; plain error. |

**L3 seam:** later, promote becomes “new `addons/<id>/<version>/` + flip current”; Update UX stays.

## 7. Namespaced ids (phase 6 / 0031)

Finishable migration — not a paper-only format lock.

### 7.1 Shape and collisions

| Topic | Decision |
|---|---|
| Form | `<publisher>.<job>` — e.g. `jugnu.clip-tools`. |
| publisher | `[a-z0-9]+`; first-party reserved: `jugnu`. |
| job | Existing kebab rules (no leading `.`). |
| Surfaces | Manifest `id`, registry `id`, `addons/<id>/`, config keys, command index, state dirs — all full id. |
| Display | Human `name` unchanged; search uses titles/keywords. |
| Collisions | `jugnu.*` wins over other publishers when multi-source exists. Among non-`jugnu.*`, **first installed wins**. |
| **Refuse UX** | Second install of a conflicting non-`jugnu` id → **hard fail** with plain copy naming the occupying addon. Recovery: user uninstalls the occupant, then installs the desired one. No silent overwrite; no auto-migrate between publishers. |
| Helpers | Un-namespaced in 0058 (`python-runtime`, `clock`). Seam: optional `jugnu.` prefix if third-party helpers ever exist. |

### 7.2 Migration

1. Rewrite first-party `addon.yaml` + `registry/addons.json` to `jugnu.<job>`.
2. `dependencies` and cross-refs use full ids.
3. On launch: migrate installed tree **per addon id**, resumably:
   - For each remaining un-prefixed `addons/<job>/`: atomically rename addon dir → `addons/jugnu.<job>/`, then migrate that id’s config enable key and `state/<job>/` (and per-addon config paths) in the same unit of work.
   - Persist progress so a crash mid-pass leaves some ids migrated and some not — **expected and recoverable**. Next launch continues with remaining un-prefixed ids.
   - Marker under state written only when **no** un-prefixed first-party addon dirs remain.
4. Do **not** require a single all-or-nothing flip of the entire tree.
5. `JUGNU_ADDON_PATH`: namespaced manifests required; un-prefixed dirs unsupported after migration completes for that tree.
6. Recents/favorites: remap `job` → `jugnu.job` best-effort; drop unreappable entries.

Half-migrated trees remain loadable: migrated ids load under `jugnu.*`; not-yet-migrated ids still load under old names until their turn (or until sources are only namespaced and old dirs are gone).

## 8. Seams (document only — not built in 0058)

| Future | How 0058 leaves the door open |
|---|---|
| Signing / notarization | Pluggable trust before extract |
| L3 side-by-side versions | Commit promotes a staged tree to a live identity; identity layout can change without new Update/deps UX; exact-version refuse may become “install alongside” |
| Multi-registry | Host allowlist + namespaced ids + collision refuse; second source is later config |
| Bundles (0048) | Ordered multi-install using the dependency transaction |
| Sandbox (0021) | Privilege model unchanged; integrity only governs what lands on disk |

## 9. Errors

All new and changed installer failures map through `UserFacingError` — plain language, no raw stderr, stacks, or temp paths in UI. Opaque `unzipFailed`-style cases are replaced with specific cases where the user can act.

Representative cases: missing/invalid sha256, blocked host / redirect, unsafe archive, oversize archive, shell too old (install), addon requires newer shell (load), non-universal binary, dependency missing/cycle/version mismatch/collision, update/replace aborted (previous kept), replace declined (process running), namespace migration item failed (retryable).

## 10. Testing

Each phase is Done only with automated coverage for its rows:

| Phase | Must prove |
|---|---|
| 1 | zip-slip / symlink / absolute / oversize rejected; sha256 required at **both** former skip sites; off-allowlist redirect cancelled via session delegate; local directory install skips hash but still stages |
| 2 | crash mid-stage → no live tree; cancel cleans staging; upgrade/reinstall commit → old or new, never mixed; **replace while addon has tracked process → accept kills / reject aborts**; helper stage+commit (not live-write) |
| 3 | `minShellVersion` install gate; load-time not-runnable on shell downgrade without uninstall; thin Mach-O rejected; `#!` exec allowed without `lipo`; `validate-addon.sh` aligned |
| 4 | topo order; cycle fail; exact version mismatch refuse; rollback removes transaction-created addons **and** helpers; deps installed disabled; collision refuse in dep resolve |
| 5 | badge when registry newer; update preserves enable + state; failure keeps old |
| 6 | per-item migrate resume after simulated mid-pass crash; collision refuse UX; remapped recents |

Manual smoke (epic close): install / cancel / upgrade / dep disclosure / replace-under-running / one namespaced install on a Mac.

## 11. Epic Done criteria

- All six phases shipped and tested.
- Tickets **0018, 0025, 0029, 0031, 0043** marked Done with link to this spec; **0058** Done.
- [addon-manifest.md](../addon-manifest.md), registry docs, and [release-process.md](../release-process.md) updated for new fields and trust rules.
- Security audit zip-slip seed closed or re-verified fixed.
- **Every** new `AddonInstallerError` (and related) case has a `UserFacingError` mapping — no generic “Something went wrong” fallthrough for installer failures.

## 12. Implementation note

No code in the design phase. After this spec is **Approved**, write an implementation plan under `docs/superpowers/plans/` that sequences the six phases with tasks and tests. Prefer finishing one phase end-to-end before starting the next. Plan must kill both sha256 skip sites and replace helper live-write with stage+commit in the same integrity phases that introduce them.
