# Jugnu — keep current (app + addons + first launch)

**Date:** 2026-09-07  
**Status:** Approved  
**Plan:** [2026-09-07 keep current](../superpowers/plans/2026-09-07-keep-current.md)  
**Epic:** [ticket 0063](../tickets.md)  
**Absorbs (when phases Done):** [0017](../tickets.md) app fetch/swap · [0062](../tickets.md) keep-current consent · [0004](../tickets.md) first-run catalog  
**Depends on:** [Install integrity](./2026-09-05-addon-install-upgrade-integrity-design.md) (0058 pipeline + catalog Update), [Shell surface](./2026-08-23-shell-surface-presets.md) (`confirm` + `pushCatalog`), [Catalog browse](./2026-08-23-addon-catalog-browse-design.md) (`recommended` tag), [Release process](../release-process.md)  
**Amends:** [0058 §6](./2026-09-05-addon-install-upgrade-integrity-design.md) “Auto: Never” — still never *silent*; this epic adds one global keep-addons switch with a bulk confirm  
**Not this spec:** Sparkle · Developer ID / notarization (signing plugs into the 0058 trust seam, same pipeline) · 0825 prefs rail IA ([launcher-catalog](./2026-08-25-launcher-catalog-design.md) Addons → Updates) · menu-bar visual ([0056](../tickets.md)) · onboarding *tour* of the menu bar / tools launcher ([0053](../tickets.md) / [0056](../tickets.md) open questions) · delta patches, update channels, background update daemon · `session` IPC ([0059](../tickets.md))

## 0. Purpose

Jugnu is a trusted installer that happens to be a Mac app. Addons and helpers already update through one sha256 pipeline. The `.app` does not. A user who downloads Jugnu once drifts onto a stale shell, and first launch still installs a hardcoded starter set instead of the catalog.

This epic is one product: **keep current**. The shell, addons, and helpers share one trust story. Sparkle is not the destination — it would be a second updater for a platform whose product *is* the installer. Signing later sits on the 0058 seam, not a migration off this path.

## 1. Locked product

| Topic | Decision |
|---|---|
| App apply | Even with keep-app on: prompt **“Jugnu {version} is ready. Update and restart?”** Never silent relaunch. |
| Addon apply | Even with keep-addons on: one prompt **“{n} addons have updates. Update all?”** Then the existing 0058 install pipeline. Not per-card, not unattended. |
| Defaults | Both switches **on**. |
| Launch check | After the shell is up (not on the hotkey paint path), **every launch** if that switch is on. **Later** dismisses until the next launch. No daily timer. |
| First launch | Two steps: (1) keep-current toggles + existing ⌘Space opt-in, (2) full catalog with `recommended` pre-selected. Then the wizard closes and in-panel Browse opens. |
| Skip | Each step has Skip. Skip on (1) keeps both switches **on** (and leaves ⌘Space off). Skip on (2) installs **nothing extra** and still opens Browse. |
| Manual check | Menu **Check for Updates** (and the same action in Preferences) always fetches. Apply still confirms. Works with switches off. |
| Catalog Update | Per-addon **Update** badge/action stays (0058 phase 5). Keep-addons off means launch does not bulk-prompt; cards still work. |
| Long-term guts | Same pipeline as addons: registry row → allowlisted download → required sha256 → path-safe extract → replace. Apply/relaunch is a **thin helper**, allowed to die the day a signed bundle can `replaceItemAt`. No deltas, no Sparkle, no background agent. |

## 2. Goals and non-goals

### Goals

- A published `Jugnu.app` can learn a newer shell exists, verify it, and replace itself after confirm.
- Keep-app / keep-addons are independent yaml facts, shown at first launch and changeable in Preferences.
- Launch checks never run before first paint and never send clipboard, commands, or paths.
- Addon bulk update reuses `AddonInstaller.install` (deps, helpers, replace-under-running). No second updater.
- First launch picks from the real catalog; `recommended` is data, not a parallel ID list in the wizard.

### Non-goals

- Sparkle, notarization, Developer ID, or a homemade equivalent (channels, deltas, SUUpdater chrome).
- Relocating a Downloads/translocated app into `/Applications`.
- Rebuilding the 0825 Preferences rail. This epic adds an **Updates** section to today’s `PrefsView`; the rail binds the same keys later.
- A menu-bar badge, notification, or tour of the status item.
- Auto-enabling newly installed addons on bulk update (preserve enabled, same as 0058).
- Publishing the first shell zip in this spec — release-process rows are the contract; the first asset can land with the first shell tag.

## 3. Trust architecture

One installer family. The app is another package, not a special download.

```
check (registry JSON, SemVer)
  → user confirms
  → AllowlistedDownloadSession
  → require sha256
  → ZIPFoundation extract (same zip-slip rules as 0058)
  → package gates
  → apply
```

| Kind | Registry | Live dest | Apply |
|---|---|---|---|
| Addon / helper | `addons.json` / `helpers.json` | `addons/<id>/` or `helpers/<id>/<version>/` | 0058 atomic commit |
| Shell | `registry/jugnu-app.json` | the running `Jugnu.app` bundle | thin restart helper (§6) |

Signing later: optional verify beside/after hash, **before** extract — the 0058 seam. Do not invent a second trust path.

Do **not** run the shell zip through `AddonInstaller` as if it had `addon.yaml`. Reuse download, hash, extract, allowlist. New Core type owns app-package gates and the apply plan.

## 4. App registry

File: `registry/jugnu-app.json` in this repo (raw `main` for v0, same as `addons.json`).

URL derivation (match helpers): if `shell.registry_url` ends in `addons.json`, replace that suffix with `jugnu-app.json`; otherwise a dedicated `shell.app_registry_url` is not added — fail closed with plain copy if the catalog URL is a non-standard shape.

```json
{
  "id": "jugnu.shell",
  "name": "Jugnu",
  "version": "0.2.0",
  "minMacOS": "14.0",
  "url": "https://github.com/Mshardul/jugnu/releases/download/shell-v0.2.0/Jugnu-0.2.0.zip",
  "sha256": "<hex>",
  "notes": "optional one-line subtitle for the confirm"
}
```

| Field | Rule |
|---|---|
| `id` | Must be `jugnu.shell`. |
| `version` | SemVer. Compare to running `CFBundleShortVersionString` with the same helper as `AddonUpdate` / `PackageGates.compareSemVer`. |
| `minMacOS` | If the running OS is older, do not offer the update; plain copy. |
| `url` | HTTPS, host allowlist identical to 0058. Zip of the app, not a DMG. |
| `sha256` | Required, non-empty. Empty → hard fail (no skip path). |
| `notes` | Optional; if present, confirm subtitle. Never required. |

Zip layout: **exactly one** `Jugnu.app` at extract root, or exactly one child directory that contains it. Multi-root → fail.

App-package gates (after extract, before apply):

- Bundle exists, `CFBundlePackageType` is `APPL`.
- `CFBundleIdentifier` is `app.jugnu.shell`.
- Marketing version equals the registry `version` (mismatch → fail; refuse a zip that does not match the row).
- The executable is a universal Mach-O (`arm64` + `x86_64`), same bar as addon `exec` entrypoints.

## 5. Config and skip rules

User intent lives in **config** (`jugnu.yaml`), not `UserDefaults`.

```yaml
shell:
  keep_app_current: true      # default true when omitted
  keep_addons_current: true   # default true when omitted
```

Keys: `keep_app_current` / `keep_addons_current` under `shell`. Independent. Prefs and first-run write both.

Omitted keys decode as **true** (product default). Existing installs that already completed first-run inherit that default on upgrade; Preferences is the off-ramp. Do not re-show first-run.

### Launch check does not run when

- `firstRunCompleted` is false at process start (wizard owns that launch).
- Screenshot mode.
- `#if DEBUG`, or the bundle path contains `.build/` or `DerivedData`.
- `JUGNU_SKIP_APP_UPDATE` is set (non-empty) — app check only; addon bulk still follows its switch.
- The running bundle is not a `.app` or the dest is not writable (app check: skip silently on launch; manual Check for Updates explains).

Addon launch check uses the same “after shell is up / first-run already done” gate; it does not use the debug/bundle skip except Screenshot mode (dev builds still have addons).

### Timing

`applicationDidFinishLaunching` (or equivalent after menu bar + hotkey are up): `Task` the check. **Forbidden** on the key-down → first-paint path ([conventions](../conventions.md) hot path).

Order if both have work: **app confirm first**. Update-and-restart skips the addon prompt this launch. Later on the app still allows the addon bulk prompt the same launch.

Offline / registry error on launch: **silent**. Next launch retries. Manual Check for Updates maps through `UserFacingError`.

## 6. App apply (thin helper)

On confirm:

1. Download zip to `~/.local/share/jugnu/state/app-update/.staging/<uuid>/` (`JugnuPaths.appUpdateStagingDir`).
2. Hash, extract, gates.
3. Copy a **tiny POSIX script** into `app-update/` (outside the bundle being replaced). The script: wait until the recorded pid is gone (bounded), `ditto` source `.app` onto `Bundle.main.bundleURL`, best-effort clear quarantine xattr, `open` the dest, delete staging.
4. Record pid + source + dest next to the script.
5. Spawn the script, then terminate Jugnu (existing quit path: `killAll` tracked addon processes first — 0057).

Replace **in place**. Do not move Downloads → Applications.

If dest is not writable: do not spawn; plain copy to move Jugnu into Applications and use Check for Updates.

Crash mid-download: staging is leftover; next launch deletes `app-update/.staging/**` (same orphan rule as 0058 `.staging`). A helper that already started must finish or fail closed (previous bundle remains if `ditto` never started). Do not build a second recovery UI.

This helper is disposable. Do not add progress UI, delta encoding, or a privileged helper tool.

## 7. Addon bulk

When keep-addons is on (launch) or when Check for Updates runs:

1. Fetch catalog (cache OK, same `RegistryClient.fetchWithCache`).
2. Diff installed versions vs registry with `AddonUpdate.isAvailable`.
3. If none, stop (manual check: “You’re up to date.” toast or in-prefs copy).
4. Confirm with the count. Cancel = Later.
5. For each newer id, call the same `install` path as catalog Update (preserve enabled, dep disclosure, helpers, replace-under-running). Sequential. One addon’s decline-while-running skips that id and continues; do not abort the rest.
6. Helpers follow the new pin (0058). Last-consumer cleanup unchanged.

0058 catalog **Update** is unchanged.

## 8. Surfaces

### 8.1 First launch (existing first-run window, two pages)

Keep **one** dedicated first-run window (today’s `FirstRunWindow` family). Do not host this in `KeyablePanel` (the user does not know the hotkey yet). Do not add a third window class.

| Step | Content | Continue | Skip |
|---|---|---|---|
| 1 | Keep Jugnu up to date (on). Keep addons up to date (on). ⌘Space opt-in (off, same copy as today). | Writes both yaml keys; next page. | Writes both keys **true**; ⌘Space stays off; next page. |
| 2 | Every registry addon as a checkbox list (`name` + `summary`). `recommended` tag pre-checked. Not the full viewB chrome. | Install checked (enable true). Close window. `pushCatalog`. | Install nothing. Close window. `pushCatalog`. |

Window size may grow on step 2. Tokens/theme: same Firefly path as other shell UI.

Registry down on step 2: cached catalog if present; else error copy + Skip still works. Local-directory fallback (today’s `recommendedLocalRoots`) only for checked ids that exist on disk when the network install fails — same idea as `completeFirstRun` today, not a second catalog.

`ShellConfig.recommendedAddonIDs` stays the fallback when tags are missing; the **UI source of truth** is the `recommended` tag on registry rows. Do not keep a third hardcoded list in the view.

After this launch, `firstRunCompleted` is true. Closing the window via the red traffic light = Skip remaining steps (same writes as Skip on the current page, then Browse). Do not trap them in the wizard.

0008 door: `pushCatalog` after close. Invoke hotkey while the wizard is up: still allowed (0008); do not block the palette.

### 8.2 Preferences

New **Updates** section on current `PrefsView` (not the 0825 rail):

- Toggle keep app current
- Toggle keep addons current
- Running version (`CFBundleShortVersionString`)
- **Check for Updates**

Same yaml keys the 0825 Addons → Updates row will bind later.

### 8.3 Menu bar

Add **Check for Updates…** above Quit (normal menu, not recovery menu). Same action as Preferences.

### 8.4 Confirms

Reuse the in-panel `confirm` preset (`ConfirmView` / `UIDescriptor`). `orderFront` the `KeyablePanel` with `confirm` on the stack (from `[launcher]`); do not leave a confirm on a hidden panel. Copy:

- App: title “Update Jugnu?”; message “Jugnu {version} is ready. Update and restart?”; confirm “Update and Restart”; cancel “Later”. Optional `notes` as extra body.
- Addons: title “Update addons?”; message “{n} addons have updates. Update all?”; confirm “Update”; cancel “Later”.

Do not use `NSAlert` or a notification.

## 9. Errors

All new failures map through `UserFacingError`. No temp paths, hashes, or stderr in UI.

Representative cases: app registry unreachable (manual only), invalid/missing sha256, blocked host, unsafe zip, version/id mismatch, not universal, macOS too old, dest not writable, helper spawn failed, addon bulk item failed (name the addon; continue others).

## 10. Privacy

Launch/manual fetch: app-registry JSON and (if keep-addons or manual) addon catalog + release zips. No clipboard, command ids, or file paths on the wire.

[PRIVACY.md](../../PRIVACY.md) network sentence includes the app registry when keep-current is on.

`JUGNU_SKIP_APP_UPDATE` is a dev/test hatch, not a user pref.

## 11. Phase map

Finish each phase before starting the next.

| Phase | Delivers | Absorbs |
|---|---|---|
| 1 | `jugnu-app.json` schema + `RegistryClient` fetch + SemVer / skip / minMacOS compare in Core. No UI. | 0017 check half |
| 2 | Download, hash, extract, app gates, thin helper, in-place replace. Tested against a fixture zip, not a live GitHub release. | 0017 apply half |
| 3 | Yaml keys, Prefs Updates, menu item, launch check, app confirm. | 0062 prefs |
| 4 | Addon bulk confirm on launch + manual check. | 0062 addons |
| 5 | Two-step first-run + Browse handoff. | 0004 |

## 12. Testing

| Phase | Must prove |
|---|---|
| 1 | Newer / same / older / invalid SemVer; minMacOS blocks; empty sha256 refused; URL derivation from `addons.json`; skip when DEBUG path / env. |
| 2 | Zip-slip rejected; id/version mismatch refused; thin Mach-O refused; staging orphan cleaned on next “launch”; helper script written outside the bundle path. |
| 3 | Default keys true; toggles persist; launch check not on hot path (unit: invoked from did-finish, not panel show); Later does not download. |
| 4 | Bulk lists only newer ids; Cancel downloads nothing; sequential install preserves enable; running-addon skip continues; catalog Update still works with keep-addons off. |
| 5 | Skip step 1 writes both true; Skip step 2 installs zero; Continue step 2 installs checked including non-recommended; `pushCatalog` after close; `recommended` tag drives pre-check. |

Manual smoke: walk [shell-smoke.md](./shell-smoke.md) keep-current section (to be added in the plan) on a Mac — Check for Updates, Later, a fixture app zip replace, first-run Skip/Continue.

## 13. Docs to update when shipping

- [release-process.md](../release-process.md) — shell zip + `jugnu-app.json` sha256 row
- [registry/README.md](../../registry/README.md) — app registry file
- [PRIVACY.md](../../PRIVACY.md) — app registry fetch
- [0058 §6](./2026-09-05-addon-install-upgrade-integrity-design.md) — Auto row points here
- Tickets **0017, 0004, 0062** Done with link; **0063** Done

## 14. Epic Done criteria

- All five phases shipped and tested.
- A real `registry/jugnu-app.json` can be published (may point at a future `shell-v*` asset; empty unpublished URL is not shipped — if the app is not released yet, the file exists with the current version so checks no-op until the first newer tag).
- No Sparkle dependency. No second download stack beside `AllowlistedDownloadSession`.
- First-run no longer installs only `recommendedAddonIDs` without showing the catalog.

## 15. Implementation note

No code in the design phase. After this spec is **Approved**, write `docs/superpowers/plans/2026-09-07-keep-current.md`. Prefer one phase end-to-end before the next. The apply helper stays the smallest script that can ditto-and-open; if it grows a privileged helper or a progress window, the plan is wrong.
