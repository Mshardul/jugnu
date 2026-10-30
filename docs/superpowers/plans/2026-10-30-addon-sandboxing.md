# Addon Sandboxing (0021) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, this session). Steps use checkbox (`- [ ]`) syntax. Mark a step done only after its verification command passes.

**Goal:** Enforce what an addon can touch (files, network) with a per-invocation macOS Seatbelt profile, so `permissions` in `addon.yaml` stops being disclosure-only. Same rules for first-party and third-party addons.

**Status:** Plan only. No spec and no code yet; the ticket row is unchanged. Decisions below were agreed in chat on 2026-10-30. Revised the same day twice: after a full plan review (errors E1–E4, gaps G1–G8) and after an outside review (points R1–R6, see "Review fixes" at the end).

## Decisions (agreed)

1. **Mechanism:** Seatbelt applied at spawn, behind one thin wrapper type so the mechanism can be swapped. **Fail closed:** if the sandbox cannot start, the addon does not run.
2. **Posture:** deny-by-default for every addon, first-party included. No tier-based bypass.
3. **Files:** the profile is generated per invocation from the shell's **grant set** (decision 6), never from the request. An addon gets its own folder (read), its state dir (read/write), its config dir (read-only, decision 16), temp, system read-only paths, and exactly the grants the shell holds for that invocation chain. Network is off unless `network` is declared.
4. **Limits stay disclosed:** Seatbelt does not restrict Jugnu's own TCC grants (Accessibility, screen recording). It also cannot contain work an addon delegates to another process: `open` asks LaunchServices to launch an app or open an item, `osascript` sends Apple events to other apps, `shortcuts run` starts a Shortcut. The delegate runs outside the sandbox, so an addon allowed to do these can do whatever those apps can. These "delegating" capabilities are deny-by-default like everything else, must be declared, and the disclosure says plainly that Jugnu cannot limit what `open`, `osascript` or `shortcuts` do afterward. Disclosure stays; this plan does not replace it.
5. **Rollout:** measure first in log-only mode, then enforce for everyone.
6. **File grants (revised 2026-10-30 after outside review R1 and R6):** files reach a command **only from shell-owned sources**; an addon never chooses a path that becomes a grant.
   - **Sources:** Finder menu and queue, tray drops, the Finder-context provider (decision 13), and an open panel the shell runs before spawning (`pick`, 4B.4). The shell keeps these as a **grant set** and builds the profile from it.
   - **Session memory:** the grant set lives for the whole invocation chain (the first run plus its follow-up requests while the panel session is open) and is dropped when the session ends. Follow-ups such as a password field arrive without paths; the addon may reload paths from its own state (PDF Tools keeps `pending-pdf` there), but that file is addon-writable and is **never** trusted. The shell's grants decide.
   - **Compatibility:** the shell keeps passing paths to the addon as it does today, in `args.paths` as an **array** of strings ([JugnuApp.swift:249](../../../shell/App/JugnuApp.swift), [ShellHost.swift:426](../../../shell/Sources/JugnuUI/ShellHost.swift)). The profile is built from the grant set, not from `args`.
   - **Grant kinds (a command declares which it may receive):** `selection` (`read` or `read-write` on the handed items; recursive for folders), `beside` (`read-write` on the direct children of each selected item's parent folder, non-recursive; this exposes sibling files in that folder, and the confirm copy says "files in the same folder"), and named `locations` (decision 10).
   - **No manifest-named path args.** A form field or any addon-supplied string never becomes a grant.
   - **Sensitive-tree backstop:** a deny list applied last, fixed in the spec before 4A: `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, `~/.netrc`, `~/Library/Keychains`, `~/Library/Mail`, `~/Library/Messages`, `~/Library/Safari`, browser profile folders, Jugnu's own config, other addons' state, and the sandbox profile directory. A user selection inside one of these is blocked with a "protected location" message.
7. **Measurement depth (agreed 2026-10-30):** scripted runs for `oneshot`/`exec` commands, a manual pass list for panel- and TCC-driven commands. Not every command is measured automatically.
8. **Already-published addons (agreed 2026-10-30):** new zips declare a sandbox-ready manifest key (name decided in the spec, for example `sandbox: 1`). A shell with enforcement treats an addon without it as "needs update": it does not run and the card offers Update. No legacy broad profile. Release order is **three releases** (E1): (1) a shell with tolerant decoding of every closed value (decision 18) and no enforcement; (2) the addons release carrying the marker and new ids; (3) the enforcing shell. Verified from code: today `RegistryEntry` throws on an unknown permission id and `RegistryClient.fetch` decodes the list all-or-nothing, so publishing a new id first would blank the catalog on every existing shell.
9. **Daemons (agreed 2026-10-30, amended by review E3):** the profile is static and `ProgramArguments` runs through the launcher. The profile file lives in a **shell-owned directory the addon cannot write** (for example `~/.local/share/jugnu/sandbox/<id>/`), never in the addon's state dir, and the profile denies that directory. Otherwise a compromised daemon could widen its own profile and let launchd's `KeepAlive` restart it with the widened one. If the sandbox is unavailable, bootstrap is skipped with the Phase 3 message.
10. **Named locations (agreed 2026-10-30, extended by R2):** fixed-location access is declared by name from a closed, shell-owned list. The shell maps each name to paths **and to the operations it allows there** (read, write, exec, move children to Trash). Manifests never carry raw paths. Adding a location is a shell release and is disclosed. Expected members, to be confirmed by Phase 1: `homebrew` (read and exec under both `/opt/homebrew` and `/usr/local` prefixes, plus the Homebrew cache), `temporary-folder` (read/write, and move its direct children to Trash), `clock-data` (read/write on `state/clock/`, shared by the clock helper).
11. **`apple-events` is one coarse id (agreed 2026-10-30):** no target-app list, because Seatbelt cannot enforce which app receives Apple events and a declared list would be a promise the shell cannot keep.
12. **Permission ids (revised 2026-10-30, R3):** five new ids: `apple-events`, `open-items`, `shortcuts` (delegating, they reach outside the sandbox), and `process-list` and `process-signal` (Seatbelt treats listing and signalling as separate operations; the reason `apple-events` stays coarse does not apply here; to be confirmed in Phase 0). **Disclosure groups follow the effect on the user, not the mechanism:** "Files it can use" (from the `files` block), "Can send data off your Mac" (`network`), "Can read other apps' data" (`clipboard`, `input-monitoring`, `screen-recording`, `camera`, `microphone`, `process-list`), "Can control other apps or the system" (`accessibility`, `apple-events`, `open-items`, `shortcuts`, `process-signal`), and "Runs in the background" (`background`). Nothing network- or clipboard-related is described as "inside the sandbox". The first-party declaration table is re-audited against Phase 1 (R2 found at least `focus-toggle` under-declares).
13. **Shell-owned context provider (agreed 2026-10-30):** for "current Finder folder / selection", the shell asks Finder with its own Automation permission and passes the result to the addon in `args.paths` like any other selection. Addons that only needed Finder for this (for example `open-terminal-here`) lose their own `apple-events` need.
14. **Execution order (review E2):** Phase 0 → Phase 1 → **4A** (model, validation and the `ResolvedFiles` type, pulled forward because Phase 2 needs them) → Phase 2 → Phase 3 → 4B–4E → Compatibility (C) → Phase 5 → flip the default to `enforce` → Phase 6. Phase 3 ships with the default mode `off` (Debug may use `enforce`), so nothing is enforced before the vocabulary, the first-party declarations and the release steps exist. 4A consumes the **Phase 1-verified** access table, not the draft table in this plan.
15. **Go/no-go gates and dogfood:** after Phase 0 and after Phase 1 the plan stops for a decision with the user (criteria in each phase). Before the default flips, the enforcing build runs on this Mac in `enforce` for a trial period with every first-party addon exercised.
16. **Config dir is read-only by default (review suggestion):** addons get read-only access to their config dir unless Phase 1 shows an addon needs to write there.
17. **Per-command permissions (agreed 2026-10-30, R3):** `permissions` is addon-wide today (only on `AddonManifest`). A command may declare its own `permissions` as a **subset** of the addon's list; the profile for that command uses the subset (absent means the addon-wide list, so existing manifests keep working). The install confirm shows the union. File grants are already per command, so this keeps the model consistent and stops a future "list" command from inheriting "signal".
18. **Tolerant decoding of every closed value (agreed 2026-10-30, R4):** any unknown value in a closed vocabulary (permission id, location, grant kind, sandbox version, and any vocabulary added later) in the registry or in a manifest means "this addon needs a newer Jugnu". The addon is shown with that state, cannot be installed or run, and is **never silently dropped and never blanks the catalog**. One generic mechanism ships in release 1 and every later closed field must use it from the release that introduces it.
19. **Each id turns on something specific (agreed 2026-10-30, R5):** the baseline profile never includes the mach services and operations behind the delegating and process ids (LaunchServices, Apple events, Shortcuts, process info, signal). A permission id adds exactly its fragment. As defense in depth, exec of a shell-owned list of delegating binaries (`open`, `osascript`, `shortcuts`, `launchctl`, `security`, and others fixed in the spec) is denied last unless the matching id is declared. The enforcement comes from withholding the underlying services; the binary deny list is the second layer, because an addon can ship its own binary.

Verified on this Mac (2026-10-30): `sandbox-exec` works (man page marks it DEPRECATED); a deny-network profile made curl fail DNS; a deny-read profile on `~/Documents` made `ls` fail with "Operation not permitted".

## Global Constraints

- **Git:** do not run git, branch or commit (`AGENTS.md`).
- **Python:** `uv run python` / `.venv` only. File edits with the Edit tool.
- **Swift comments:** none above declarations (SwiftFormat's `docComments` rule then demands `///`). At most one `//` why-line inside a body. No `///`, no `// MARK:`.
- **Never run a repo-wide formatter.** Check with `swiftformat --lint --config .swiftformat shell/Sources shell/Tests shell/TestsExtended shell/App` and fix by hand.
- **Every phase ends green:** `cd shell && swift test`, `make lint-swift` (0 errors), swiftformat lint (0 files), `make spell`, `make test`.
- **Layering:** profile text generation lives in JugnuCore (pure, no AppKit). Spawn integration in `AddonRunner`. UI and disclosure copy in JugnuUI/App.
- **Packaging rules still apply** ([AGENTS.md](../../../AGENTS.md)): no new user-visible concept beyond Addon / Commands / Helper; helpers stay shell-downloaded.
- **Not this plan:** zip signing, moving the daemon gate (audit F7) onto the trust tier, TCC reset (0022), permission glyphs (0051).
- **Do not derive facts from word searches.** The draft access table was built from a grep over `bin/` scripts and picked up `open` from `api.open-meteo.com`. Every table row must come from reading the code path or from a trace.

## File map

| Path | Phase | Responsibility |
|---|---|---|
| `docs/release-process.md` | C | Release order: tolerant shell, then addons with the marker, then the enforcing shell |
| `docs/architecture/2026-10-30-addon-sandboxing-design.md` | 0 | Spec: profile model, grant vocabulary, sensitive-tree list, rollout, limits (written after the spike) |
| `shell/Sources/JugnuCore/Sandbox/SandboxProfile.swift` | 2 | Pure builder: effective permissions + `ResolvedFiles` + dirs → SBPL text and `-D` parameters |
| `shell/Sources/JugnuCore/Sandbox/ResolvedFiles.swift`, `SandboxGrantError.swift` | 4A | Grant types and typed errors, defined before Phase 2 |
| `shell/Sources/JugnuCore/Sandbox/SandboxLauncher.swift` | 3 | Wraps the spawn: executable, arguments, fail-closed startup check |
| `shell/Sources/JugnuCore/AddonRunner.swift` | 3 | Spawn through the launcher; Release mode `off | enforce` (`log` is Debug-only) |
| `shell/Sources/JugnuCore/RegistryClient.swift`, `Models.swift` (`RegistryEntry`), `ManifestLoader.swift` | C.0 | Generic tolerant decoding of closed values; "needs a newer Jugnu" state |
| `shell/Sources/JugnuCore/Permissions/AddonPermission.swift`, `Models.swift`, `Install/PackageGates.swift` | 4A | New ids, per-command permissions, `CommandFiles`, validation |
| `shell/App/` grant session store, Finder-context provider, open-panel picker, `Info.plist` | 4B | Shell-owned file sources and session grants; Automation usage description |
| `addons/jugnu.pdf-tools` (`Sources/pdf-tools/main.swift`) | 4C | Drop the in-addon `NSOpenPanel`; the shell runs the picker |
| `scripts/validate-addon.sh`, `scripts/build-registry.sh` | 4C | Mirror the new manifest rules; registry copy |
| `scripts/sandbox-run.sh` | 4C | Author tooling: run an addon command under its profile and show denials |
| `shell/App/DaemonAgents.swift`, `ClockHost.swift` | 5 | Launchd daemons and the clock helper through the launcher |
| `shell/Tests/JugnuCoreTests/Sandbox*Tests.swift`, `shell/TestsExtended` | 2–6 | Golden profiles; live escape tests |
| `.github/workflows/` | 6 | Optional macOS job for the live escape tests (first run happens on the user's push) |

## Phase 0 — Spike and spec

Goal: replace assumptions with measured facts before any design is written.

Spawn sites the sandbox must cover (read 2026-10-30): `AddonRunner.swift:134` (every addon command) and `DaemonAgents.swift:123-131` (launchd `ProgramArguments`). `ClockClient.swift:142` is a shell-owned helper binary and gets its own profile. `FinderQuickActions`, `JugnuApp.swift:202`, `Cleanup`, `PackageGates` spawn trusted shell tools and are not sandboxed.

- [ ] **0.1** Confirm `(trace "<file>")` in a profile records the accesses a run needs (the mechanism Phase 1 relies on). If it does not work, record the fallback (parse the unified log for sandbox denials) and use that for Phase 1.
- [ ] **0.2** Run one real addon of each entrypoint kind under a deny-default profile by hand: an `exec` bash addon (`jugnu.focus-toggle`), a `jxa` addon (`jugnu.brew-outdated`), and one using the `python-runtime` helper (`jugnu.clip-tools`). Record which allowances each needs and what fails first (dyld cache, `/usr/bin` tools, locale files).
- [ ] **0.3** Confirm fail-closed behavior: bad profile, missing `sandbox-exec`, and sandbox-already-applied (nested) all produce a non-zero exit that the runner can detect and tell apart from an addon's own failure. If they cannot be told apart, the launcher needs a handshake (a reserved exit code).
- [ ] **0.4** Check how a launchd daemon plist can run through the wrapper (`ProgramArguments`) and whether the `clipboard-history` watcher and `keep-awake` (`caffeinate`) survive deny-default.
- [ ] **0.5** Check inheritance: do tools an addon itself spawns (for example `osascript`) inherit the profile, and does anything break?
- [ ] **0.6** Decide profile delivery: inline `-p` string versus a per-run file. A file shows exactly what was applied but needs cleanup; decide on injection safety and debuggability.
- [ ] **0.7** Confirm `sandbox-exec` execs in place (the child keeps the pid the shell spawned), because run markers, the reaper and `kill(pid)` depend on it. If it forks, the launcher must change (for example a tiny exec shim).
- [ ] **0.8** Check whether an unprivileged app can read the sandbox denials for a child pid (unified log, sender `Sandbox`), how fast, and whether it works for a child of an app without extra permissions. Failure kind 2 in Phase 3 depends on this. If it does not work, the fallback is a generic "blocked" message with no file or network detail, and Phase 3.3 is amended in the spec.
- [ ] **0.9** Check the shell-owned profile directory (decision 9): the addon's profile denies it, a sandboxed process cannot write there, and `sandbox-exec -f` can still read it.
- [ ] **0.10** Check path forms the profile must handle: `/tmp` versus `/private/tmp`, `/var/folders` temp dirs, firmlinked `/Users` paths, and case variants (`~/.SSH` on case-insensitive APFS) against a deny rule.
- [ ] **0.11** Enforcement mapping (R5, decision 19): under a baseline-only profile (no capability fragments), `open`, `osascript`, `shortcuts` and a signal to another process must **fail** because the underlying services are withheld. Record exactly which mach services and operations each permission id has to add. Confirm `process-info` can be allowed without `signal` (decision 12).
- [ ] **0.12** Check whether `NSOpenPanel` works at all inside a Seatbelt-sandboxed AppKit process and whether the user's selection becomes readable. The design does not rely on it (the shell runs the picker, decision 6), but the result decides how loudly the `pdf-tools` change in 4C is flagged.
- [ ] **0.13** `beside` semantics (R1): confirm a rule for "direct children of the parent folder, non-recursive" can express PDF Tools' pattern (stat candidate names until one is free, create the file, read it back, atomic replace) and record what it exposes.
- [ ] **0.14** Write `docs/architecture/2026-10-30-addon-sandboxing-design.md` from the findings: profile template, the grant vocabulary (decision 6), the **sensitive-tree list** (R6), the delegating-binary list (decision 19), `shell.sandbox` mode config, daemon/helper handling, known limits, **and a Plan B** (G5): if `sandbox-exec` is removed or stops working, a small shell-owned launcher calls the sandbox API directly; list the trigger conditions and keep `SandboxLauncher` minimal so it can be swapped. Mark it **Draft — awaiting user review**; do not mark Approved or touch the ticket until the user approves.

Verification: spec exists; each decision above is either confirmed by a recorded command output or amended in the spec with the reason.

**Go/no-go gate 1 (with the user):** stop and decide if any of these holds: sandbox startup failure cannot be told apart from an addon failure and no handshake works; `jxa`/`osascript` addons cannot run under any workable deny-default profile; `sandbox-exec` does not exec in place and no shim fixes it; denials cannot be read and the generic fallback is judged too weak; the delegating ids cannot be withheld in the baseline (decision 19).

## Phase 1 — Measure (log-only)

- [ ] **1.1** Fixture set: for each addon, the representative arguments and the files to select. Commands that cannot run unattended (permission prompts, UI panels, TCC-driven) go on a manual pass list instead. For every file-processing command, record **where output goes** (next to the input, a temp file in the same folder for atomic replace, a fixed location), whether the input is a file or a folder, and whether the follow-up requests reload paths from the addon's own state (G2, R1).
- [ ] **1.2** Debug-only trace run of the scripted commands under an allow-default profile with trace enabled (script under `scripts/`, bash or `uv run`, not shipped).
- [ ] **1.3** Manual pass: walk the manual list on this Mac with trace enabled and record results.
- [ ] **1.4** Aggregate per addon: paths read/written, network use, mach services, verdict (fits deny-default / needs vocabulary / needs fixing). Store the table in the spec, not in the repo root. This table drives the Phase 4 vocabulary and **replaces** the draft table below.
- [ ] **1.5** Flag addons whose needs break decision 3 or 6 (commands that find their own files, such as `open-terminal-here`, or open a panel themselves, such as `pdf-tools`). Each becomes a finding: pass the path from a shell source, add a capability, or change the addon, decided with the user.
- [ ] **1.6** Record whether any addon writes to its config dir (decision 16), reads other addons' roots (dependencies), writes into a helper folder (for example Python writing `__pycache__` into the `python-runtime` helper), or writes helper data files (R2).
- [ ] **1.7** For every first-party addon, compare declared `permissions` with what the trace shows and list under-declarations (R2: `focus-toggle` declares none today).

Verification: every first-party command has a recorded access set; open findings listed in the spec.

**Go/no-go gate 2 (with the user):** review the access table. Stop and decide if more than a few addons cannot fit deny-default without widening the vocabulary beyond the agreed shape, or if an addon needs a grant that would make its profile meaningless (for example the whole home folder).

### Draft expected needs (corrected 2026-10-30 from reading the scripts; Phase 1 replaces this table)

| Addon | Entry | Declared permissions | What the code actually does | Expected sandbox needs |
|---|---|---|---|---|
| `jugnu.audio-toggles` | exec | none | `osascript` | Apple events (system audio); no files |
| `jugnu.battery-eta` | exec | none | `pmset` | read power state; no files |
| `jugnu.brew-outdated` | exec (jxa) | network | `doShellScript` runs `/opt/homebrew/bin/brew` or `/usr/local/bin/brew` | `homebrew` location: exec at **both** prefixes, cache access; network; `apple-events` (JXA host). Stress case. |
| `jugnu.clip-tools` | exec | clipboard | `python3` from the `python-runtime` helper | pasteboard; helper read/exec; selection text only |
| `jugnu.clipboard-history` | exec + daemon | clipboard, background | `pbcopy`, `pbpaste` | pasteboard; own state dir read/write; daemon profile |
| `jugnu.floating-note` | exec | none | none | own state dir only |
| `jugnu.focus-toggle` | exec | none (**under-declared**) | `shortcuts list` and `shortcuts run`; fallback clicks Control Center through System Events (UI scripting) | `shortcuts`, `apple-events`, `accessibility` |
| `jugnu.intervals` | exec (jxa) | none | spawns the clock helper itself; the helper writes `~/.local/share/jugnu/state/clock/timers.json` | `clock` helper read/exec, `clock-data` location read/write, `apple-events` (JXA host, notifications) |
| `jugnu.keep-awake` | exec + daemon | background | `caffeinate` | power assertion service; daemon profile |
| `jugnu.open-terminal-here` | exec | none | asks Finder for the front folder, then opens Terminal | folder from the Finder-context provider (decision 13); `open-items` |
| `jugnu.pdf-tools` | exec + Swift helper | none | Finder selection as an `args.paths` array; creates files beside the input and reads them back; reloads paths from `pending-pdf` in its state dir on follow-ups; palette runs call `NSOpenPanel` itself | `selection: read-write` or `read` + `beside: read-write`, `pick: open`; own helper binary; state dir |
| `jugnu.ports` | exec | none | `lsof`; kills processes | `process-list`, `process-signal` |
| `jugnu.temporary-folder` | exec + jxa | none | `cp -R` of a dropped item into `~/Temporary`; trashes direct children with `NSFileManager.trashItem` | `temporary-folder` location (read/write, move children to Trash); `selection: read` (recursive for folders); `apple-events` (JXA host) |
| `jugnu.weather-bar` | exec | network | `curl` only (the earlier `open` was `api.open-meteo.com` in the URL) | network |
| `jugnu.window-layouts` | exec + Swift helper | accessibility | none beyond the helper binary | Accessibility mach service; own state |
| `jugnu.world-clock`, `jugnu.ui-demo-*` | exec | none | none | own state dir only |

What this implies:
- Today's closed `permissions` set (accessibility, input-monitoring, camera, microphone, screen-recording, network, clipboard, background) does not name Apple events, opening apps or items, Shortcuts, or process listing and signalling. The first-party declaration table in the permissions design (section 3.5) needs re-auditing, and the vocabulary needs new ids (Phase 4).
- Several addons depend on `osascript`/JXA as their host or fallback; Phase 0.2 and 0.11 decide what a JXA host needs by default.
- `open-terminal-here` and `pdf-tools` find or pick files themselves today. Both change so that files come from shell-owned sources (4C).
- `ports` and `brew-outdated` are the stress cases for deny-default. `ports` can signal any user process and see other apps' command lines.

## Phase 2 — Profile builder (pure)

Profile skeleton (what the builder emits; exact baseline allowances come from the Phase 0 spike, not from guesses):

1. `(version 1)` then `(deny default)`.
2. Baseline every process needs: read of system libraries, frameworks and the dyld cache; `process-exec` of system tool directories (`/bin`, `/usr/bin`, `/usr/sbin`, `/usr/libexec`, `/System`); `file-read-metadata` for path resolution; `/dev/null`, `/dev/urandom`; locale and timezone data; a minimal `mach-lookup` and `sysctl-read` set. **The baseline never includes the services behind the delegating and process ids** (decision 19, verified in Phase 0.11).
3. Addon-specific, from inputs only: read and exec of the addon root; read and exec of declared helper roots and of the roots of addons it depends on (G7); read and write of the addon's own state dir; read-only on its own config dir (decision 16); temp dir.
4. Capability fragments, one per permission id **effective for this command** (decision 17), each a small pure function with its own golden test: `network`, `clipboard` (pasteboard service), `background`, `accessibility` (AX service), `apple-events`, `open-items`, `shortcuts`, `process-list`, `process-signal` (Phase 4A ids).
5. Grants from `ResolvedFiles` (defined in 4A.5): `selection` and `beside` and `locations`, canonicalized.
6. Deny rules applied last: the sensitive-tree list from the spec (decision 6), the shell-owned sandbox profile directory from decision 9, and the delegating-binary list unless the matching id is effective (decision 19). Ordering is part of the tested contract.

- [ ] **2.1** `SandboxProfile` is a pure function: `(effective permissions, ResolvedFiles, dirs, helper and dependency roots) → profile text + parameters`. No I/O. `ResolvedFiles` and the error type come from 4A; Phase 2 does not define them.
- [ ] **2.2** Paths enter the profile as `-D` parameters, never spliced into profile text. Reject paths with quotes or control characters.
- [ ] **2.3** Paths are canonicalized (resolve symlinks, standardize) before use. This explicitly covers `/tmp` → `/private/tmp`, `/var/folders` temp dirs and firmlinked paths. A target that does not exist yet is canonicalized through its **parent directory** plus the literal file name.
- [ ] **2.4** Rule ordering is part of the tested contract (Seatbelt rules are order-sensitive).
- [ ] **2.5** Golden-file tests: one profile per shape (no files, selection read, selection read/write, `beside`, location with exec, network on, helper present, each capability fragment, process-list without process-signal).
- [ ] **2.6** Hostile-input tests: a path containing `")(allow default)` must not widen the profile; a symlink inside an allowed folder pointing at `~/.ssh` must not open `~/.ssh`; case variants (`~/.SSH`) and `/tmp` versus `/private/tmp` forms must not bypass a deny rule; a grant inside the sensitive-tree list is rejected; `open` and `osascript` stay denied unless their id is effective.
- [ ] **2.7** Grant semantics from the Phase 0.13 and Phase 1 findings: a selected file → literal rule; a selected folder → recursive subpath rule; `beside` → direct children of the parent folder only (a non-recursive pattern covering read, create, write and the same-folder rename and unlink that atomic replace needs; sibling reads are exposed and disclosed); a plain `write` never covers atomic-replace temp files.

Verification: `swift test` green with the new tests; lint and format clean.

## Phase 3 — Spawn integration and fail closed

Today a non-zero exit with no valid JSON becomes `RunResponse(ok: false, error: <raw stderr>)` ([RunningInvocation.swift:53-58](../../../shell/Sources/JugnuCore/RunningInvocation.swift)). A sandbox block would reach the user as whatever the addon prints. This phase gives the sandbox its own failure categories and maps the typed errors from 4A to copy.

- [ ] **3.1** `SandboxLauncher` returns executable and arguments for a command; `AddonRunner.spawn` uses it for every entrypoint kind (`exec`, `jxa`, `osascript`) and every lifecycle class (`oneshot`, `job`). Pid-keyed run markers and `kill(pid)` keep working only if the wrapper execs in place (Phase 0.7).
- [ ] **3.2** Config `shell.sandbox` with `decodeIfPresent` so old `jugnu.yaml` files load. **Release supports `enforce` and `off` only; the shipped default is `off` until the flip step (decision 14), then `enforce`.** `log` is a Debug-only measurement mode (agreed 2026-10-30): a user-visible log mode would let addons run unsandboxed and add a state to explain. `off` is shown prominently in Preferences when set.
- [ ] **3.3** Failure kinds, kept separate:

  | Kind | Detection | User sees |
  |---|---|---|
  | Sandbox could not start | launcher pre-check or reserved exit code (Phase 0.3) | "Jugnu couldn't start this addon safely." The addon does not run. Never falls back to unsandboxed. |
  | Grant rejected before spawn | typed `SandboxGrantError` from 4A (protected location, no grant where one is required, path that cannot be canonicalized) | "<Addon> can't use that location." The addon does not run. |
  | Addon blocked by the profile | non-zero exit, then a lookup of the sandbox deny log for that pid, **on the failure path only** | "<Addon> was blocked from <file or network>." Details in a diagnostic log file. |
  | Addon's own failure | unchanged | unchanged |

  Messages go through `UserFacingError`. No "allow this once" prompt in this plan (agreed 2026-10-30); a message is enough. If Phase 0.8 shows denials cannot be read, the blocked kind falls back to a generic message with no file or network detail.
- [ ] **3.3a** Diagnostic log (G4): file paths are user data, so the log is local only, never uploaded, paths redacted to `~`, capped in size with rotation and a short retention, and records only addon id, command id, the denied operation class and the redacted path. It follows the privacy rules in `docs/conventions.md` (Privacy and trust) and ticket 0001's "ids and timings, never payload" spirit; exact numbers are fixed in the spec.
- [ ] **3.4** Self-test: after first paint, run a trivial sandboxed command once and keep the result in memory. If it fails, the sandbox is "unavailable": in enforce mode addons refuse to run with one clear message instead of each failing differently. The result is independent of the `LaunchGuard` crash counter, so a macOS change cannot push the app into safe mode.
- [ ] **3.5** Child environment stays the allow-list from the audit F5 fix.
- [ ] **3.6** No per-addon opt-out. Third-party addons cannot switch the sandbox off. A user-level "allow more for this addon" control is out of scope.
- [ ] **3.7** Speed gate: measure with `InvokeTrace` before and after on a toast addon and a list addon. The wrapper may not push command-to-toast past the 150 ms target (hard ceiling 400 ms); if it does, investigate before enforcing.
- [ ] **3.8** Unit tests with a fake runner: launcher argument building, failure classifier, typed-error mapping, mode decoding (missing key, unknown value).
- [ ] **3.9** Live escape tests in `shell/TestsExtended` (not in CI's `swift test`): a fixture addon that tries to read `~/Documents`, write outside its state dir, and reach the network without declaring it must fail; the same fixture with a declared allowance must pass.
- [ ] **3.10** Keep `SandboxLauncher` minimal (executable, arguments, startup check) so the Plan B launcher from the spec can replace `sandbox-exec` without touching callers (G5).

Verification: unit tests green; extended tests green on this Mac (using test-only manifests built with 4A, per decision 14); speed gate met. With the shipped default `off`, behavior for users is unchanged; the "every first-party addon still runs under enforcement" pass happens at the flip step, after Phase 4 and the Compatibility steps.

## Phase 4 — Manifest vocabulary and disclosure

Manifest shape (key names provisional, final names fixed in the Phase 0 spec):

```yaml
sandbox: 1
permissions: [network, apple-events, shortcuts]   # addon-wide ceiling
commands:
  - id: pdf-merge
    permissions: [network]        # optional: this command's subset; absent = the addon-wide list
    files:
      selection: read-write       # on the items the shell hands over; recursive for folders
      beside: read-write          # direct children of each selected item's parent folder (non-recursive)
      pick: open                  # shell runs an open panel first when no selection arrives
      locations: [temporary-folder]
```

Current state (read 2026-10-30): `AddonPermission` is a closed enum of 8 ids ([AddonPermission.swift](../../../shell/Sources/JugnuCore/Permissions/AddonPermission.swift)); `permissions` exists only on `AddonManifest`, not on `CommandDescriptor` ([Models.swift:460](../../../shell/Sources/JugnuCore/Models.swift)); the shell hands selections to addons as `args.paths` arrays.

### 4A — Core model and validation (executed right after Phase 1, before Phase 2: decision 14)

- [ ] **4A.1** `AddonPermission` gains `apple-events`, `open-items`, `shortcuts`, `process-list`, `process-signal`, each with display title, reason, a `delegating` flag (true for `apple-events`, `open-items`, `shortcuts`) and a disclosure group from decision 12 (effect-based: off-Mac, other apps' data, control, background).
- [ ] **4A.2** `SandboxLocation`, a closed enum of named locations with a shell-owned table of paths **and allowed operations** (read, write, exec, move children to Trash), per decision 10. Members come only from the Phase 1-verified table.
- [ ] **4A.3** `CommandFiles` on `CommandDescriptor`: `selection` (`read` | `read-write`), `beside` (`read-write`), `pick` (`open`), `locations`. And optional `permissions` on `CommandDescriptor` (a subset of the addon list; validated). `effectivePermissions(for:)` returns the command's subset or the addon-wide list. All decoding uses the tolerant mechanism from C.0 for unknown values, with strict errors only for malformed structure.
- [ ] **4A.4** `ManifestLoader` and `PackageGates` validate: closed values only; no raw paths anywhere in `files`; no path-valued args; a command `permissions` list is a subset of the addon's. The ready marker rule lands with its manifest updates (4C.1 / 4C.3 / C.1 are one change).
- [ ] **4A.5** Types defined here, before Phase 2 uses them: `ResolvedFiles` (canonical grants of kind `selection` / `beside` with access, plus resolved locations) and `SandboxGrantError` (protected location, grant required but missing, uncanonicalizable path, grant not declared by the command). The runner returns these typed errors; **Phase 3 maps them to copy**. A command with no `files` block receives no file grants at all.
- [ ] **4A.6** Capability mapping table, next to the ids: each permission id → the exact operations, mach services and binaries it enables (filled from Phase 0.11). The baseline excludes all of them. The delegating-binary deny list is data in this table, applied last by the builder (decision 19).

### 4B — Shell-owned file sources and session grants

- [ ] **4B.1** `GrantSession` in the shell: created from the first run's source, reused by every follow-up request of the same panel session, dropped when the session ends. Grants are never read from the request, the addon's state or anything else the addon controls (decision 6).
- [ ] **4B.2** Record grants at the points where the shell already receives paths: Finder menu and queue, tray drops (`JugnuApp.swift:249`, `ShellHost.swift:426` and `:446`). Paths are arrays; the shell keeps passing them in `args.paths`.
- [ ] **4B.3** Finder-context provider (decision 13): asks Finder for the front folder or selection using the shell's Automation permission, on demand, **only** for palette invocations of commands that declare `selection` (the Finder menu and queue already carry paths). It needs the Automation usage description in the shell's `Info.plist` and goes through the existing pre-TCC explainer (0054 A). It adds a Finder round-trip to those commands, which the Phase 3 speed gate measures against the 150 ms target.
- [ ] **4B.4** Shell-run picker (`pick: open`): if a command declares `pick` and no selection arrives, the shell shows an open panel before spawning (types from the command's `finder.types` when present). The result becomes a `selection` grant and is passed in `args.paths`. This replaces the in-addon `NSOpenPanel` calls (Phase 0.12 only decides how loudly to flag it).
- [ ] **4B.5** Access is exactly what the command declared (`selection: read` never yields write); a grant inside the sensitive-tree list fails with `SandboxGrantError` (protected location).
- [ ] **4B.6** Mid-flow pickers (an addon asking for more files after it started) are out of scope; see Open questions.

### 4C — Tooling, registry and addon changes

- [ ] **4C.1 / 4C.3 / C.1 land as one change (R5):** `validate-addon.sh` starts requiring the ready marker in the same change that adds the marker (and the Phase 1-verified declarations) to every first-party `addon.yaml`. Otherwise the validator fails the whole tree. Each manifest is updated and validated one addon at a time inside that change; run `./scripts/sync-registry-commands.sh --check` at the end.
- [ ] **4C.2** `scripts/build-registry.sh` emits `sandbox`, `permissions` (existing field) and the union of declared `locations` and `files` grants, so disclosure works before download. `RegistryEntry` decodes them with the tolerant mechanism (missing marker → needs update; unknown value → needs a newer Jugnu).
- [ ] **4C.4** Author tooling (G8): `scripts/sandbox-run.sh <addon-dir> <command>` runs a command under the profile the shell would build and prints the denials, so third-party authors can develop against the sandbox. Documented in `docs/addon-manifest.md` and `CONTRIBUTING.md`. `validate-addon.sh` stays static and cannot catch runtime denials; the docs say so.
- [ ] **4C.5** Addons whose behavior changes, each a separate task, each keeping its commands and UI working and none merged or renamed (AGENTS packaging rules): `pdf-tools` drops its two in-addon `NSOpenPanel` calls (`main.swift:135`, `:150`) and relies on `pick: open`, and declares `selection` plus `beside`; `open-terminal-here` takes its folder from the shell; `focus-toggle` gains its missing declarations (`shortcuts`, `apple-events`, `accessibility`); `intervals` declares the `clock-data` location and the `clock` helper; `temporary-folder` declares its location and `selection: read`; `brew-outdated` declares `homebrew`; `ports` declares `process-list` and `process-signal`. The final list comes from Phase 1.

### 4D — Disclosure

- [ ] **4D.1** The Permissions body on card and detail groups by effect (decision 12): "Files it can use", "Can send data off your Mac", "Can read other apps' data", "Can control other apps or the system", "Runs in the background". Delegating ids carry the plain sentence that Jugnu cannot limit what `open`, `osascript` or `shortcuts` do afterward (decision 4). Grants are stated in plain words ("Read the files you select", "Create and change files in the same folder as the ones you select", "Homebrew folder"). Nothing network- or clipboard-related is described as contained.
- [ ] **4D.2** Install confirm shows the union of the commands' permissions and grants. Update re-confirms when anything grew, extended to the new ids, any new location, `beside`, `pick` or widened `selection` access (existing "grew-only" mechanism).
- [ ] **4D.3** Re-audit the first-party declaration table in the permissions design (section 3.5) against the Phase 1 results and update it, including under-declarations found in Phase 1.7.
- [ ] **4D.4** `docs/addon-manifest.md` documents the new keys, the per-command `permissions`, the closed lists and the rule that files only come from shell-owned sources.

### 4E — Tests

- Core: decoding (valid, unknown id, unknown location, unknown grant kind, unknown sandbox version, subset rule for command permissions, missing marker), `ResolvedFiles` construction, typed errors, access never widened, grants rejected inside the sensitive-tree list.
- Sources: `args.paths` arrays produce grants; follow-up requests without paths reuse the session grants; a forged `pending-pdf`-style file in the state dir grants nothing; the picker runs only when `pick` is declared and no selection arrived; the Finder-context provider runs only for commands that declare `selection`.
- Contract: `validate-addon.sh` against fixtures for each rule; all first-party addons pass.
- UI: all disclosure groups (including `network` and `clipboard` outside any "inside the sandbox" wording), grew-only re-confirm for each kind of growth.

Verification: all first-party addons pass `validate-addon.sh`; registry sync check passes; unit and UI tests green; lint and format clean.

## Compatibility and release order

All first-party zips in the registry (`addons-v1.0.0`) predate any sandbox vocabulary. A shell that enforces deny-default would break every installed addon that needs files or network until it is updated (decision 8). Separately, today's shells cannot read a registry entry or manifest with a value they do not know (E1), so the order of releases matters twice over.

- [ ] **C.0** Release 1, tolerant shell (no enforcement), per decision 18: a generic mechanism that decodes any closed value to an `unknown` sentinel instead of throwing; `RegistryClient.fetch` decodes entries one by one so one bad entry never blanks the catalog; an entry or an installed manifest with **any** unknown closed value (permission id, location, grant kind, sandbox version, anything added later) is shown as "needs a newer Jugnu" with no install and no run, never silently dropped. `ManifestLoader` maps vocabulary errors to the same state while real syntax errors still throw. This is valuable on its own and does not depend on the rest of the plan. Record the rule "new closed fields use this mechanism from the release that introduces them" in `docs/conventions.md` and the spec. Tests: one bad entry among good ones leaves the catalog usable; each kind of unknown value → "needs a newer Jugnu"; the entry stays visible.
- [ ] **C.1** Ready marker: the manifest key from decision 8. `ManifestLoader` reads it; `build-registry.sh` emits it (registry copy, so the card can show "needs update" before download). The validator requirement lands with 4C.1 / 4C.3 as one change.
- [ ] **C.2** Shell behavior when the marker is missing: do not spawn; show "<Addon> needs an update to run safely" with the existing Update action. Keep-current (0063) already updates addons by default, so most users never see it.
- [ ] **C.3** Release order, written into `docs/release-process.md`: (1) **tolerant shell** (C.0), then wait until keep-current has moved users onto it; (2) **addons release** whose zips carry the marker, the new ids and the Phase 4 declarations (tolerant shells show "needs a newer Jugnu" for entries they cannot read, never a blank catalog); (3) **enforcing shell**, default flipped to `enforce` (decision 14); its first launch runs the keep-current addon check before the first addon command.
- [ ] **C.4** A shell must not enforce against a registry that has not yet been republished: gate on the registry entry's marker, so a stale registry shows "needs update" instead of silently breaking.
- [ ] **C.5** Tests: marker missing → refused with the right message; marker present → runs; registry entry without marker → card shows needs-update.
- [ ] **C.6** Flip the default to `enforce` only when: the dogfood trial (decision 15) passed, every first-party addon passes the per-addon smoke under enforcement, and the speed gate is met.

Verification: with the old `addons-v1.0.0` zips installed, a sandbox-enforcing build shows "needs update" for each addon and none runs unsandboxed; after Update, they run.

## Phase 5 — Daemons and helpers

Facts (read 2026-10-30): `DaemonAgents.writePlist` builds `ProgramArguments` from the addon program plus args, with only `JUGNU_ORIGIN` and `JUGNU_SHELL_START_TS` in the environment ([DaemonAgents.swift:123-141](../../../shell/App/DaemonAgents.swift)). Only `keep-awake` and `clipboard-history` are daemons. `ClockClient.run` spawns the clock helper directly every 2 seconds ([ClockHost.swift](../../../shell/Sources/JugnuCore/ClockHost.swift)) and never sets a child environment, so it inherits the whole shell environment (the same gap as audit F5). The `intervals` addon also spawns the clock helper itself, which writes `state/clock/timers.json`, shared with the shell's own client.

- [ ] **5.1** Static daemon profile: written at bootstrap into the **shell-owned profile directory** (decision 9, outside the addon-writable state dir), regenerated on every bootstrap; `ProgramArguments` becomes `sandbox-exec -f <profile> <program> …`. It allows only the addon's own dirs, its log files and what the daemon needs (`clipboard-history`: the pasteboard service; `keep-awake`: `caffeinate`), as measured in Phase 0.4 and Phase 1. Label rules from the audit (`com.<id>.*`) unchanged.
- [ ] **5.2** Fail closed without a crash loop: if the sandbox is unavailable (Phase 3.4 self-test), skip bootstrap and show the Phase 3 message. Otherwise launchd's `KeepAlive` would restart a failing wrapper every few seconds. Re-bootstrap when the sandbox becomes available.
- [ ] **5.3** Clock helper (shell side): its own profile (read the helper folder, read/write the `clock-data` location, no network) and the F5 environment allow-list. Measure the wrapper cost for the 2-second poll (about 30 extra execs a minute) in the Phase 3 speed gate. If it is too costly, that is a separate change (for example a long-lived helper), not part of this plan.
- [ ] **5.4** Helper roots as read-only allowances for addons that declare them (`python-runtime`, `clock`), via the Phase 2 builder inputs. **Helper data files** (R2): an addon that spawns a helper which writes data (`intervals` and the clock helper) declares the matching named location (`clock-data`); the helper inherits the addon's profile, so the location must be in it. Helper processes the shell spawns itself get their own profile.
- [ ] **5.5** Scripted lifecycle checks in place of a manual walk: `launchctl print` and plist presence before and after enable, disable and uninstall for both daemons; assert the plist runs through the launcher. Login and reboot behavior stay manual, and only with the user's go-ahead.
- [ ] **5.6** Unit tests for the plist builder: wrapper arguments, profile file location outside the state dir, no plist written when the sandbox is unavailable, and the profile denies its own directory.
- [ ] **5.7** Upgrade path (G1): daemons already bootstrapped by an older shell keep running unsandboxed from their old plists. On the first launch of the enforcing shell, `syncEnabled` boots out and re-bootstraps every enabled daemon through the launcher (or boots it out if the addon lacks the marker), and verifies with `launchctl print` that the running job uses the wrapper. Test: a plist written by the old builder is replaced.

Verification: `keep-awake` and `clipboard-history` work after enable; disable removes the agent and the profile as before; scripted lifecycle checks pass.

## Phase 6 — Close out

- [ ] **6.1** User reviews and approves the spec; only then set its status to Approved. Until then the spec stays "Draft — awaiting review" and the ticket stays "Not started".
- [ ] **6.2** Update the 0021 ticket row (Status, Last updated, dated Remarks note appended; keep original text) and backlog item 10 / the permissions design "Later still" row.
- [ ] **6.3** Docs that must change with the feature: `SECURITY.md` and `PRIVACY.md` (they describe the trust model without a sandbox), `docs/release-process.md` (release order), shell-smoke (manual item for the blocked-addon message and the needs-update state), the permissions disclosure design (effect-based groups, enforced vs disclosed-only), `docs/addon-manifest.md` (new keys), `docs/conventions.md` (tolerant closed values rule).
- [ ] **6.4** Update the security audit prompt: add sandbox enforcement as a check, and refresh the stale sections noted in the 2026-10-29 report. Also fix the stale "known debt" row about `unzip()` in `docs/conventions.md`.
- [ ] **6.5** Scan `feedback_claude_mistakes.md` against the diff before reporting done. Run all checks from Global Constraints.
- [ ] **6.6** `make install` only when the user asks.
- [ ] **6.7** CI: add a macOS job that runs the live escape tests (GitHub macOS runners include `sandbox-exec`) as a release gate. I cannot validate a workflow locally, so the first run happens on the user's push; the plan does not claim it works until that run is green.
- [ ] **6.8** Follow-up tickets, one row each in `docs/tickets.md` using the house format: tolerant registry decoding if it ships separately, per-addon behavior changes found in Phase 1, mid-flow pickers, an args schema for commands, a general `trash` grant for future trash addons, and any later "allow once" prompt.

## Test strategy (all phases)

| Layer | What | Where | Runs in CI |
|---|---|---|---|
| Unit | Profile builder golden files, hostile-input cases, capability fragments, grant sources and session memory, mode decoding, failure classifier, typed-error mapping, launcher arguments, plist builder, marker handling | `shell/Tests/JugnuCoreTests` | yes (`swift test`) |
| Contract | `validate-addon.sh` rejects unknown vocabulary and missing marker; accepts all first-party addons; registry sync check | `scripts/`, `make ci` | yes |
| Live escape | A fixture addon that reads `~/Documents`, writes outside its state dir, opens the network undeclared, follows a symlink to `~/.ssh`, runs `open` or sends a signal without the matching id, and (daemon case) tries to rewrite its own profile: all must fail; with declarations they must pass | `shell/TestsExtended` | not yet; macOS job proposed in 6.7 |
| Upgrade | Registry with one unreadable entry, each kind of unknown closed value, old-builder daemon plist, addon without the marker | `shell/Tests/JugnuCoreTests` | yes |
| Per-addon smoke | Each first-party addon, every command, under enforcement, scripted where possible | script under `scripts/`, run on this Mac | no |
| Speed | `InvokeTrace` before and after on a toast addon, a list addon, a Finder-context command and the clock poll | manual, recorded in the spec | no |
| Manual | Blocked-addon message, protected-location message, needs-update state, picker, login and reboot daemon behavior | shell-smoke | no |

A change to any layer must keep `swift test`, `make lint-swift`, swiftformat lint, `make spell` and `make test` green.

## Open questions (resolve in Phase 0 or with the user)

- **Mid-flow pickers:** `pick: open` runs before the first spawn only. If an addon needs to ask for more files later in a chain, that needs a protocol addition (a descriptor asking the shell to pick). Deferred; decide when a real addon needs it.
- Does the sandbox apply cleanly to a child that is itself an installed helper binary (`pdf-tools`, `window-layouts`) that uses Accessibility? If Seatbelt cannot express what it needs, that addon declares the TCC capability and the profile allows the required mach service.
- Is a per-run profile file or `-p` string safer for path injection and logging? Decide from the Phase 0 spike.
- Exact wording of the Phase 3 messages (copy decision before Phase 3 ships), and of the disclosure group headings in 4D.1.
- Name of the sandbox-ready manifest key and whether it carries a version (`sandbox: 1`) so the profile model can change later without another flag day.
- Where the "needs an update to run safely" and "needs a newer Jugnu" states appear in the palette (disabled row with Update action, or hidden) and how keep-current orders addon updates before the first command after a shell update.
- What the session boundary is for the grant set in `ShellHost` (panel close, new invocation, timeout), settled in the spec after reading how follow-ups are routed.
- Whether a general `trash` grant is needed for future addons (the backlog has `trash-ui`); today it exists only inside the `temporary-folder` location.

## Review fixes

First review (E and G findings, 2026-10-30):

| Finding | Where it landed |
|---|---|
| E1 release order breaks old shells | Decisions 8 and 18; Compatibility C.0, C.3, C.6 |
| E2 Phase 3 verified before Phase 4 | Decisions 14 and 15; 4A before Phase 2; Phase 3.2 default `off` |
| E3 daemon profile writable by addon | Decision 9; Phase 5.1, 5.6; Phase 2 deny list; Phase 0.9 |
| E4 `process-control` called "contained" | Decision 12; 4A.1; 4D.1 |
| G1 running daemons survive upgrade | Phase 5.7 |
| G2 output and atomic-write handling | Phase 1.1; Phase 2.3, 2.7 |
| G3 reading denials unverified | Phase 0.8; Phase 3.3 fallback |
| G4 diagnostic log holds paths | Phase 3.3a |
| G5 no Plan B for `sandbox-exec` | Phase 0.14; Phase 3.10 |
| G6 Finder-context provider costs | 4B.3; 4E; Phase 3.7 |
| G7 dependency roots | Phase 2 skeleton item 3 |
| G8 author tooling | 4C.4 |
| Case/path forms, config read-only, gates, dogfood, CI | Phase 0.10; Phase 2.3, 2.6; decisions 14 to 16; gates 1 and 2; 6.7 |

Outside review (2026-10-30), each point checked against the code before acceptance:

| Point | Verdict | Where it landed |
|---|---|---|
| R1a `create-beside` cannot express PDF Tools | Confirmed (`PDFFiles.destination` stats names, `write` reads the file back) | Decision 6 `beside`; Phase 0.13; Phase 2.7 |
| R1b `paths` is an array | Confirmed (`JugnuApp.swift:249`, `ShellHost.swift:426`, `:446`) | Decision 6 compatibility; 4B.2 |
| R1c follow-ups lose paths | Confirmed (`pending-pdf` in the state dir) | Decision 6 session memory; 4B.1; 4E |
| R1d `NSOpenPanel` inside the addon | Confirmed (`main.swift:135`, `:150`); sandbox behavior unverified | Decision 6 `pick`; Phase 0.12; 4B.4; 4C.5 |
| R2 expected-needs table wrong | Confirmed (my grep hit `open` in `api.open-meteo.com`); "frozen" overstated because 4A uses the Phase 1-verified table | Corrected table; decisions 10, 14; Phase 1.4, 1.7; Phase 5.4; Global Constraints |
| R3a disclosure grouped by mechanism | Confirmed | Decision 12; 4D.1 |
| R3b `process-control` should be two ids | Confirmed (to verify in Phase 0.11) | Decision 12; 4A.1 |
| R3c permissions are addon-wide | Confirmed (`Models.swift:460`) | Decision 17; 4A.3 |
| R4 unknown locations can blank the catalog | Partly right: C.0's per-entry skip already protects the catalog, but entries would vanish silently and only permission ids got "needs a newer Jugnu" | Decision 18; C.0 |
| R5a `ResolvedFiles` defined after its consumer | Confirmed | 4A.5 |
| R5b 4A referenced Phase 3 copy | Confirmed | 4A.5 typed errors; Phase 3.3 |
| R5c marker required before it is added | Confirmed | 4C.1 / 4C.3 / C.1 as one change |
| R5d `/usr/bin` exec makes the new ids meaningless | Partly right: the gap is real, but enforcement should come from withholding the underlying services; the binary deny list is a second layer | Decision 19; Phase 0.11; 4A.6; Phase 2 skeleton |
| R6 declared path args are addon-chosen grants | Confirmed | Decision 6 (no path args, sensitive-tree list); 4B.5; Phase 0.14 |
