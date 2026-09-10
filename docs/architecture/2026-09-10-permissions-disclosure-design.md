# Jugnu — permissions disclosure (honest capabilities)

**Date:** 2026-09-10  
**Status:** Approved  
**Plan (Now / 0038):** [2026-09-10 permissions disclosure](../superpowers/plans/2026-09-10-permissions-disclosure.md)  
**Ship slice (first):** [ticket 0038](../tickets.md) — install / first-launch / update disclosure  
**Same design, later phases:** [0054](../tickets.md) A (pre-TCC explainer) — [plan](../superpowers/plans/2026-09-10-permissions-pre-tcc-explainer.md) · [0054](../tickets.md) B (detail + prefs Permissions row; prefs chrome is [0064](../tickets.md)) · [0022](../tickets.md) (TCC reset detection)  
**Depends on:** [Shell surface](./2026-08-23-shell-surface-presets.md) (`confirm`), [Catalog browse](./2026-08-23-addon-catalog-browse-design.md) + [launcher-catalog](./2026-08-25-launcher-catalog-design.md) (card / detail Permissions tab), [Install integrity](./2026-09-05-addon-install-upgrade-integrity-design.md) (dep disclosure), [Keep current](./2026-09-07-keep-current-design.md) (first-launch Continue), [Shell design](./2026-08-22-shell-design.md) (honest permission UX, shell Permissions table)  
**Supersedes:** [2026-08-26 permissions, privacy & security](./2026-08-26-permissions-privacy-security-design.md) (findings-only)  
**Not this product:** per-addon sandboxing ([0021](../tickets.md)) · free-text permission strings · binary inference · signing / notarization · permission glyph art ([0051](../tickets.md)) · rebuilding the full 0825 prefs rail IA (this design binds keys/rows into today’s surfaces first)

## 0. Purpose

Jugnu installs addons that can read the pasteboard, talk to the network, keep a launchd agent alive, or need macOS TCC (Accessibility, Camera, …). Today the user only learns that mid-use, when the OS prompts or the command silently fails.

This is one product: **honest capability disclosure**. The shell tells the user what an addon can do **before writing files**, again **before a TCC prompt on first use**, and again **if a grant disappears after an OS upgrade**. Ticket 0038 is the first ship; 0054 and 0022 are named later phases in this document — not permanent skips.

Helpers do not declare capabilities. The **consuming catalog addon** does. Shell-owned Input Monitoring (global hotkey) and shell registry network are **not** on the addon list; they stay a shell disclosure in Later still.

## 1. Phase table (nothing skipped)

| Phase | Ticket | Ships | Does not ship yet |
|---|---|---|---|
| **Now** | [0038](../tickets.md) | Closed `permissions` on `addon.yaml` + registry copy; validate unknown ids; card one-liner; detail list (data + thin chrome); confirm before zip write if non-empty (catalog Install, first-launch Continue, install-with-deps); re-confirm only when an update’s set **grew**; merge with dependency disclosure; first-party yaml fills + packaging | Pre-TCC explainer UI; prefs Permissions page polish; TCC reset detection; glyphs |
| **0054 A** | [0054](../tickets.md) | In-app explainer immediately before the macOS TCC prompt on first use of a declared TCC capability; Open System Settings / Not now; same titles + shell-owned reasons | Prefs inventory; TCC reset |
| **0054 B** | [0054](../tickets.md) | Detail **Permissions** tab as durable home (0825 gallery + tabs); Prefs → Addons → Permissions (granted vs needed for installed addons) | Icon system |
| **0022** | [0022](../tickets.md) | Launch (or after-paint) check: shell Input Monitoring + enabled addons’ declared TCC ids; if previously granted and now denied → same explainer chrome | Periodic background polling |
| **Later still** | — | Revoke UX polish; permission glyphs ([0051](../tickets.md)); shell Input Monitoring / shell network first-run or prefs disclosure (separate from addon `permissions`) | Sandboxing ([0021](../tickets.md)) |

## 2. Locked product

| Topic | Decision |
|---|---|
| Vocabulary | Closed capability ids only. Unknown → `validate-addon` refuse and install refuse. Omit or `[]` = none. |
| Clipboard | **Any** pasteboard read/write (clip-tools, paste-plain, clipboard-history). |
| Network | This **addon’s job** uses the network (weather, brew). Not the shell’s registry / keep-current fetch. Local-only tooling (e.g. `ports` via `lsof`) does **not** declare `network`. |
| Background | launchd / KeepAlive (or equivalent) that keeps running after the panel closes. |
| Trust | Honor the declared list. Shell does not inspect binaries. First-party CI / packaging table flags missing declarations. |
| Install gate | Confirm **only if** the effective capability set is non-empty. Empty → Install proceeds with no extra sheet. |
| Multi-addon | One confirm: unique capability **titles** first; each id **expands** to the addon names that need it; then the existing dependency block when both apply. |
| Upgrade | Re-confirm only when the new zip’s set **grew** vs the installed `addon.yaml` list. Missing field on an old install counts as empty. Same-set or shrink → no extra sheet. |
| Confirm hosts | Catalog / keep-current / in-panel Update → KeyablePanel `confirm` (same family as keep-current). First-launch Continue → confirm **in the first-launch window** (not a second panel). |
| Card | One line when non-empty: `Needs Accessibility, Clipboard` (comma-joined display titles). Empty → no line. Card Install still skips Details; the confirm is the gate. |
| Detail | Full list with one-line **shell-owned** reason per id. Addon does not supply free-text. Thin chrome acceptable in Now; 0054 B matches 0825 Permissions tab. |
| macOS TCC | This list is **copy**, not a grant. The OS still prompts on first use. Phase A inserts Jugnu’s explainer **before** that prompt when the capability is not already granted. |

## 3. Capability contract

### 3.1 Closed ids

| Id | Display title | Kind | Shell-owned reason (detail + pre-TCC) |
|---|---|---|---|
| `accessibility` | Accessibility | TCC | Control other apps’ windows |
| `input-monitoring` | Input Monitoring | TCC | Observe keyboard input for this job |
| `camera` | Camera | TCC | Use the camera for this job |
| `microphone` | Microphone | TCC | Use the microphone for this job |
| `screen-recording` | Screen Recording | TCC | Capture the screen for this job |
| `network` | Network | Capability | Contact the network for this job |
| `clipboard` | Clipboard | Capability | Read or write the clipboard |
| `background` | Background agent | Capability | Keep a background agent running after the panel closes |

No other ids in v0. Extending the set is a design amendment + validator update, not an author free-for-all.

### 3.2 Manifest

```yaml
permissions:
  - clipboard
  - background
```

| Rule | Lock |
|---|---|
| Field | Optional `permissions:` list of closed ids. Omit or `[]` = none. |
| Duplicates | Dedupe on load; order does not matter for equality. Display order = table order above. |
| Helpers | Helpers have no `permissions`. Consumer addon declares what the user experiences. |
| Load | Unknown id → refuse to load / install with plain `UserFacingError` copy. |

Document under [addon-manifest.md](../addon-manifest.md) when implementing Now.

### 3.3 Registry

`RegistryEntry` gains `permissions: [String]` (default `[]`), copied from the packaged manifest the same way `dependencies` is — so Browse can disclose **before** download.

`scripts/build-registry.sh` / sync path must emit the field. Stale registry rows with a missing key decode as `[]`.

### 3.4 Validation

`scripts/validate-addon.sh` rejects unknown ids and non-list shapes. Packaging fails closed.

### 3.5 First-party declaration table (Now fill)

Authoritative for first-party packaging in this epic’s Now implementation. Update when an addon’s job changes.

| Addon id | `permissions` | Notes |
|---|---|---|
| `jugnu.window-layouts` | `accessibility` | AX on first use (existing product lock). |
| `jugnu.clipboard-history` | `clipboard`, `background` | History store + shell-owned daemon. |
| `jugnu.clip-tools` | `clipboard` | Pasteboard transforms. |
| `jugnu.paste-plain` | `clipboard` | Pasteboard strip. |
| `jugnu.weather-bar` | `network` | Fetches weather. |
| `jugnu.brew-outdated` | `network` | Invokes Homebrew / network as part of the job. |
| `jugnu.keep-awake` | `background` | Daemon / caffeinate agent. |
| `jugnu.mic-mute` | _(none)_ | Device mute via audio APIs — not Microphone TCC capture. |
| `jugnu.mute-all` | _(none)_ | Same. |
| `jugnu.ports` | _(none)_ | Local listeners; not outbound `network`. |
| `jugnu.battery-eta` | _(none)_ | |
| `jugnu.focus-toggle` | _(none)_ | |
| `jugnu.floating-note` | _(none)_ | |
| `jugnu.nudges` | _(none)_ | |
| `jugnu.pomodoro` | _(none)_ | |
| `jugnu.open-terminal-here` | _(none)_ | |
| `jugnu.world-clock` | _(none)_ | |
| `jugnu.ui-demo-*` | _(none)_ | Demos; not catalog products. |

## 4. Install / update / first-launch flows

### 4.1 Effective set

For a single catalog entry: registry `permissions` (pre-download) or staged manifest after extract — same ids. For “grew” checks: compare **new** set minus **installed** `addon.yaml` set (missing field = empty).

For multi-addon writes (first-launch checked ids; primary + will-install deps): union of each target’s permissions. Expand map: capability id → list of addon **names** that declare it.

### 4.2 Confirm copy

| Case | Title | Body | Buttons |
|---|---|---|---|
| Single install, non-empty | `Install {name}?` | `This addon will need:` + display titles (one per line or comma list — same titles) | Install / Cancel |
| Multi / first-launch, non-empty | `Install these addons?` | `They will need:` + unique display titles; disclosure control expands each title to addon names | Install / Cancel |
| Update grew | `Update {name}?` | `This version newly needs:` + **only new** display titles | Update / Cancel |
| Empty set | — | No confirm | Proceed |

When catalog dependencies also need disclosure, **one sheet**: capabilities block first, then the existing “already installed / will install / installed ≠ enabled” block (today’s `DependencyInstallDisclosure` content, migrated into the same confirm host).

Cancel writes nothing (no download commit).

### 4.3 Layering

| Layer | Owns |
|---|---|
| **JugnuCore** | Closed id enum / parse; set equality and “grew” diff; multi-addon union + expand map; `UIDescriptor` builders for confirms (mirror `confirmAppUpdateUI` / bulk addon confirm); registry decode |
| **App** | Show confirm (panel `pushFollowUp` or first-launch window); call installer only after accept; wire Browse / first-launch / Update |
| **JugnuUI** | Card one-liner; detail permissions list rendering |

Do not invent a second installer path. Gate sits **before** `AddonInstaller.install` commit (same place as dep disclosure).

### 4.4 Keep-current bulk addon update

Bulk “Update all?” (keep-addons) still confirms the bulk write. **Additionally**, if any selected update’s capability set grew, the bulk flow must include those growths in the confirm (or a follow-up confirm before those zips write). Prefer one combined confirm: bulk count + any newly needed capability titles with expand-to-addons. Cancel downloads nothing.

## 5. Surfaces

### 5.1 Catalog card (Now)

When `permissions` non-empty: one secondary line  
`Needs {Title1}, {Title2}, …`  
in display-table order. Empty: omit the line. No severity colors in Now (glyphs later).

### 5.2 Detail (Now data / 0054 B chrome)

List each declared id: **display title** + shell-owned reason. Empty: “This addon does not need special permissions.” (or equivalent plain copy).

0825 locked tab label **Permissions** stays literal. Now may render the list without the full gallery+tabs chrome if detail is still flat; 0054 B brings Overview / Commands / Permissions tabs to match [launcher-catalog §3.3](./2026-08-25-launcher-catalog-design.md).

### 5.3 Prefs → Addons → Permissions (0054 B)

For each **installed** addon: name, declared capabilities, and for TCC ids whether the OS currently reports granted (best-effort). Not a place to install/uninstall (Browse stays that). Binds into today’s prefs until the 0825 rail rebuild; do not block 0054 B on that rebuild.

### 5.4 Privacy copy

[PRIVACY.md](../../PRIVACY.md) already requires documenting addon requirements. When Now ships, amend one sentence: catalog install shows declared capabilities and confirms before download when any are listed.

## 6. Runtime pre-TCC explainer (0054 A)

### 6.1 When

On the **first use** path that would trigger a macOS TCC prompt for a capability the addon **declared**, if the shell can tell the grant is not already allowed: show Jugnu’s explainer **before** invoking the API that triggers the system prompt.

Non-TCC capabilities (`network`, `clipboard`, `background`) do **not** get this explainer at runtime — install disclosure was the gate. Clipboard/network failures stay plain command errors.

### 6.2 Copy

`{Addon name} needs {Permission title} to {shell-owned reason}.`

Buttons: **Open System Settings** (deep-link to the relevant Privacy & Security pane when possible) / **Not now**.

Not now: dismiss explainer; do not pretend the grant exists. Subsequent invoke may show the explainer again or fail with plain copy if the OS denies — prefer fail with the same permission title, not a raw stderr dump ([0019](../tickets.md) coordinates message taxonomy; do not block 0054 A on 0019).

### 6.3 Already granted

If already allowed, no explainer — run the job.

## 7. TCC reset detection (0022)

### 7.1 When

After first paint (same family as keep-current launch check — not on the hotkey paint path), once per launch:

1. Shell: Input Monitoring (or hotkey-equivalent) required for the configured global hotkey — if missing, existing fallback remains (menu bar Open palette works); surface a clear re-grant path using explainer chrome.
2. Enabled addons: for each declared **TCC** id, if the shell previously observed granted (or the user successfully used the capability) and the OS now reports denied → queue re-grant explainer(s).

Do not spam: coalesce into one panel where practical (“Some permissions were reset…” + list). **Later** on a prompt dismisses until next launch (no daily timer in v0).

### 7.2 Storage

Minimal local state under Jugnu state paths: which TCC ids were last known granted (ids + addon id only — never payloads). Loss of this state means we may re-prompt once; that is acceptable.

## 8. Revoke and later still

| Item | Lock |
|---|---|
| User revokes in System Settings while Jugnu runs | Next invoke or next launch check surfaces the gap (0022 + 0054 A). No silent success. |
| Glyphs | Placeholder text titles until [0051](../tickets.md). |
| Shell Input Monitoring / shell network | Disclose in prefs / first-launch shell section later; **not** mixed into addon `permissions` arrays. |
| Sandboxing | [0021](../tickets.md) — separate epic after security audit groundwork. |

## 9. Goals and non-goals

### Goals

- User never downloads an addon with a non-empty capability set without an explicit confirm (or empty-set fast path).
- Same vocabulary on card, detail, confirm, pre-TCC explainer, and TCC-reset prompts.
- First-launch multi-install is as honest as single Install.
- Updates that add capabilities ask again; updates that do not stay quiet.

### Non-goals (all phases unless amended)

- Inferring permissions from Mach-O / scripts.
- Free-text author reasons.
- Replacing macOS TCC prompts.
- Per-addon sandbox profiles ([0021](../tickets.md)).
- Blocking Install on “not yet granted” — disclosure is consent to **need**, not proof of grant.

## 10. Success criteria

### Now (0038)

1. Manifest + registry + validate-addon enforce the closed set.  
2. First-party table applied to packaged addons; `build-registry` emits `permissions`.  
3. Catalog Install with non-empty list → in-panel confirm → accept writes / cancel does not.  
4. Empty list → no confirm.  
5. First-launch Continue with mixed set → one confirm, unique titles, expand shows addon names.  
6. Update that adds `accessibility` → grew confirm; same-list republish → no grew confirm.  
7. Card shows `Needs …` when non-empty; detail lists titles + reasons.  
8. Dependency + permissions both present → one sheet.  
9. Automated Core tests for parse, grew diff, union/expand; UI smoke items in [shell-smoke.md](./shell-smoke.md).

### 0054 A / B / 0022

Criteria land in the implementation plan for that phase; must reuse this vocabulary and copy tables without inventing parallel ids.

## 11. Manual smoke (add to shell-smoke when Now ships)

- [ ] Install `jugnu.window-layouts` from Browse: confirm lists Accessibility; Cancel leaves no tree; Install then enable → first use still OS TCC (Phase A not required yet).  
- [ ] Install `jugnu.floating-note`: no permissions confirm.  
- [ ] First-launch Continue with recommended including clipboard + network addons: one confirm; expand shows which addons per capability.  
- [ ] Card for `jugnu.clip-tools` shows `Needs Clipboard`.  
- [ ] Detail for `jugnu.clipboard-history` lists Clipboard and Background agent with reasons.  
- [ ] Upgrade fixture: installed without `accessibility`, registry newer with it → Update confirm “newly needs”.

## 12. Implementation order

1. **Now — 0038** — Done. Plan: [2026-09-10 permissions disclosure](../superpowers/plans/2026-09-10-permissions-disclosure.md).  
2. **0054 A** — plan against §6: [2026-09-10 permissions pre-TCC explainer](../superpowers/plans/2026-09-10-permissions-pre-tcc-explainer.md).  
3. **Preferences chrome** — [0064](../tickets.md) against [launcher-catalog §3.4](./2026-08-25-launcher-catalog-design.md) (parked; unblocks 0054 B prefs row).  
4. **0054 B** — separate plan against §5.2–5.3 (after or with 0064 for prefs Permissions).  
5. **0022** — separate plan against §7.  
6. **Later still** — as tickets / design amendments.

## Related

- [PRIVACY.md](../../PRIVACY.md) — permissions at point of use; document requirements  
- [Addon manifest](../addon-manifest.md) — field home when Now ships  
- [Window layouts](./2026-08-24-window-layouts.md) — Accessibility on first use  
- Architecture index: [README](./README.md)
