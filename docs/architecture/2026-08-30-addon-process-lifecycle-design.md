# Jugnu — addon process lifecycle + crash recovery

**Date:** 2026-08-30
**Status:** Draft — under review (revised after first review pass)
**Depends on:** [Shell design](./2026-08-22-shell-design.md) (`api: 1` run protocol), [Addon UI host + speed](./2026-08-22-addon-ui-speed-design.md) (§5 protocol, §6 budgets), [Shell surface presets](./2026-08-23-shell-surface-presets.md) (stack, `hide()`), [Addon state dir + config](./2026-08-27-addon-state-and-config-design.md) (state root, `cleanup`), [Addon manifest](../addon-manifest.md)
**Not this spec:** the `session` lifecycle class in its entirety (its own epic — see §11), the `job` determinate-progress wire format, the full `daemon` authoring surface, installer atomicity / zip-slip. See §10 and §11.

## 0. Purpose

Every addon runs as an out-of-process child. Today the shell **spawns and forgets**: no reference to the `Process` or the `Task` awaiting it escapes `AddonRunner.run()`. As a direct result:

- Leaving a panel (Esc / click-outside / navigate) does not stop a running addon. The `Task.detached` keeps awaiting; the child keeps executing.
- Quitting Jugnu has no defined behaviour for a child mid-invoke.
- Sleep/wake can strand a child that should have ended.
- Re-invoking the same command while one is in flight spawns a second concurrent child.
- A crash **or hang** during startup (bad config, bad theme, bad addon) has no recovery path — the user relaunches into the same failure.
- Addons that fork background work (`( sleep 1500; notify ) & disown` in `pomodoro`) leak processes the shell cannot see, name, or reap.

This epic makes the shell the **owner** of addon process lifetime: one place that knows what is running, one set of rules for when a child dies, a launch-safety net, and a crash-durable backstop that reaps anything which escaped the fast path. It is designed for the final app — hundreds of addons, third-party, UI-first — not the current 19 fast-exit scripts.

**Scope:** three lifecycle classes — `oneshot`, `job`, `daemon`. The fourth, `session` (a live process bound to an open panel, exchanging messages), needs bidirectional IPC that is a design of its own; it is a **sibling epic** (§11), gated on the first `session`-shaped addon. The class enum is built open so adding `session` later is a manifest-parse change, not an architecture change.

## 1. Findings carried forward (locked elsewhere, constrains this epic)

- **Invoke → visible result must feel instant** ([conventions](../conventions.md), UI-host §6). Teardown on leave/quit/sleep must never make the user wait. Kills are fire-and-forget; the panel dismisses immediately.
- **The manifest is the trust boundary** ([conventions — Privacy and trust](../conventions.md#privacy-and-trust)). An addon declares intent; the shell controls the mechanism. This drives §5 (shell-generated `daemon` plists, not addon-shipped) and the §5 first-party trust gate.
- **`cleanup` is disable/uninstall-only** ([state-dir spec §2](./2026-08-27-addon-state-and-config-design.md)). Lifecycle-edge kills never run `cleanup.paths` — wiping a state dir because the user hit Esc is destructive and surprising.
- **Disable must actually stop background agents** (ticket 0023, verified). `launchctl bootout` on disable/uninstall already works for `com.jugnu.*` labels. The `daemon` class formalises this; it does not replace it.
- **Menu-bar-only, non-technical target user** ([vision](../vision.md)). Safe mode is the difference between "the app is broken, I'll delete it" and "there's a reset button" — Alfred and Raycast both ship one.
- **Single-instance guard** (ticket 0020, done). Exactly one shell process runs per user session; the reaper (§6) can assume a live Jugnu shell it sees is *this* one.
- **`api: 1` stays.** Every new manifest field is additive with a default that reproduces today's behaviour. `api: 2` is reserved for the `session` IPC stream (its own epic).

## 2. The lifecycle-class model

Each **command** declares a lifecycle class. It is the contract that tells the shell how long the child may live and which edges kill it.

| Class | Process lives | Killed on panel-leave / Esc / click-outside | Killed on app quit | Survives sleep | Re-invoke while running |
|---|---|---|---|---|---|
| `oneshot` | until it writes its one JSON object (bounded by `oneshotHardCeiling`) | yes — the awaiting task is cancelled, which terminates the child | yes | n/a (short by construction) | new spawn |
| `job` | until it writes its result; may be long; must heartbeat | **yes** + drop progress UI | **yes**, after a prompt | no | `on_reinvoke` (`reuse` \| `replace`) |
| `daemon` | until the addon is disabled or uninstalled | **no** | **no** | **yes** | always `reuse` — never a second |

### Locked decisions

| Topic | Decision |
|---|---|
| Declaration level | **Command-level** `lifecycle:`. An addon may set an addon-root `lifecycle:` as the default for all its commands. |
| Default when omitted | `oneshot`. The overwhelming common case and the safest (bounded, killed everywhere). |
| Enum is open | The parser accepts `oneshot` / `job` / `daemon` now and rejects `session` at load with a clear "session addons are not yet supported" message. Adding `session` later is a parse + handler change (§11), not an architecture change. |
| The host tracks **every** class it can kill | `AddonProcessHost` (§3) holds a live entry for every `oneshot`, `job` (and later `session`) child — this is the cancellation mechanism, and `oneshot` is where the ticket-0014 "Esc leaves a `Process`" bug actually lives. `daemon` is never in the host (§5). |
| Single-process guard is **per `(addon-id, command-id)`** | Never two concurrent `job` (or `session`) children for the **same command**. A `oneshot` from command A and a `job` from command B of the same addon coexist. `oneshot` entries are tracked but never block a re-invoke — a second `oneshot` of the same command just spawns again. `daemon` allows N per addon (one label per `daemon` command, §5) — the per-command rule is consistent across all classes. |
| `oneshot` timeout is a hard shell ceiling | Manifest may set `timeout:` but the shell clamps it to `oneshotHardCeiling`. A third-party `oneshot` must not be able to hold the palette hostage. "Instant" is a platform guarantee, not a per-addon choice. |
| `job` liveness = heartbeat, not progress | A `job` must write a newline heartbeat (a bare `\n`, or any output) at least every `jobHeartbeatWindow` while working. The shell runs a watchdog; a `job` that goes silent past the window is treated as hung → SIGKILL + error. This is **liveness only** — determinate progress frames (%, step labels) are the deferred progress protocol (§10) and ride the same channel. |
| `job` UI while running | The shared indeterminate-progress + **Cancel** chrome (the UI-host v1 "multi-second work with cancel" pattern). Cancel → `host.killTracked`. After ~60 s the label softens to "Still working — longer than usual". No wall-clock cap — a `job` is *expected* long; the heartbeat watchdog is what catches a hang. |
| Detached addon-response panels | A `oneshot` may return a `note` or `card` UI descriptor → a detached `NSPanel` the shell owns; the child has already exited. These panels are dismissed on quit and on sleep by `ShellHost`, the same as any open panel (§9). |

### Named budgets (add to `LatencyBudgets`)

| Name | Value | Meaning |
|---|---|---|
| `oneshotHardCeiling` | **10 s** | Absolute clamp on a `oneshot` invoke. The 0.8 s default runner timeout stays the *target*; this is the "obviously stuck / abusing the palette" hard kill. A legitimate 1–2 s heavy transform is fine; anything genuinely long is a `job`. |
| `jobHandshakeWindow` | **10 s** | A `job` that produces no first output within this of spawn is a failed launch (hung) → SIGKILL + error. Generous enough for a cold binary + a network auth round-trip. |
| `jobHeartbeatWindow` | **10 s** | Max silence between heartbeats for a running `job`. Same value as the handshake window — the rule is "first output OR heartbeat within 10 s, then a heartbeat at least every 10 s". |
| `killGrace` | **~500 ms** | SIGTERM→SIGKILL grace on an edge kill. |
| `replaceDeathCeiling` | **~2 s** | Max wait for a `replace`d child to actually die before the shell gives up and tells the user to retry (§7). |

### Rejected

- **`transient | persistent` (two classes).** Too coarse. A 30-second file conversion and a pasteboard watcher have different lifetimes and kill rules.
- **Host tracks only `job` (+ `session`), not `oneshot`.** Then Esc during a slow `oneshot` (network converter, `osascript` waiting on a hung app) has nothing to kill — the exact bug this epic exists to fix.
- **Per-addon single-process guard.** `daemon` already allows N-per-addon; `on_reinvoke` is inherently a per-command concept. The invariant is per-command.
- **Shell-supervised `daemon` processes.** Reinvents launchd, dies when the shell dies, does not survive sleep for free.
- **A wall-clock cap on `job`.** Kills the use case (a legit 45-min 4K convert). The heartbeat watchdog is the hang defense.
- **`ps -E` env reading for the reaper.** macOS restricts it (same-uid only, further locked for hardened / Apple-signed binaries like `osascript`). The reaper uses crash-durable marker files instead (§6).
- **Inferring the class from behaviour.** The class is an explicit contract, checked at package time.

## 3. `AddonProcessHost`

A `@MainActor` type in the **App** target, owned by `AppDelegate`, mirroring the existing `ClockHost` (`start()` / `stop()`, `AppDelegate`-held, App-layer). Not in `JugnuCore` — Core stays value-types + per-call structs only; App owns all process lifetime (clock + addons, one layer).

### Locked decisions

| Topic | Decision |
|---|---|
| Naming | `AddonProcessHost` — the job, not `Registry` / `Manager` ([conventions — Naming](../conventions.md#naming)). |
| Keyed by | **`(addon-id, command-id)`.** The value is a list of live entries for that command (normally 0 or 1; a `oneshot` re-invoke can briefly make 2). |
| Entry | `{ process, invocationTask, class, startedAt, invokeUUID, markerPath }`. |
| Every spawn is tracked | Initial invoke **and** every follow-up (`confirm` / `list` pick / `form` submit re-spawn) go through `AddonRunner.spawn()` → `RunningInvocation` → host register, deregister in `terminationHandler`. No `Task.detached`. A follow-up spawn is a `oneshot` by lifetime. |
| Single-process guard | On a `job` (or later `session`) spawn: if a live entry of that class already exists for the `(addon-id, command-id)` key, apply `on_reinvoke` (§7) instead of spawning. `oneshot` never blocks. |
| Registered | Immediately after `AddonRunner.spawn()` returns a live handle, before the response is awaited. **Spawn→register is not atomic** — a lifecycle edge firing in that window can miss a child; the wake reaper (§6) is the intended backstop for exactly this. |
| Deregistered | In the child's `terminationHandler` — whichever way it ends (normal exit, SIGTERM, SIGKILL). The spawn's marker file is deleted here too. |
| Kill API | `killTracked(key:)`, `killAll()`, `hasTracked(key:) -> Bool`, `tracked() -> [Entry]`. |
| Edge kill mechanism | Fire-and-forget: SIGTERM now, schedule a SIGKILL check after `killGrace` on a detached task, return immediately. The entry stays `dying` until `terminationHandler` confirms. |
| `killAll()` on quit is parallel + bounded | One SIGTERM broadcast, one shared `killGrace`, one SIGKILL broadcast, return. It does **not** await individual `terminationHandler`s — `applicationWillTerminate` has a hard ~5 s OS deadline. Anything still dying is the reaper's problem next launch. |
| `replace` mechanism | The user explicitly asked to replace — **SIGKILL immediately**, no polite grace. Wait for `terminationHandler` up to `replaceDeathCeiling`; on confirm, spawn the new child. If the prior is still not dead (uninterruptible IO), abandon the wait, surface "Previous run is still stopping — try again in a moment", **do not spawn**. Never two concurrent children for one command, not even briefly. |
| Re-invoke during `dying` | Treated as a live entry for the `on_reinvoke` decision. `reuse` waits for the slot; a further `replace` before the slot frees just updates the pending request (last-request-wins, no queue). Palette invokes are debounced like search (§9) so a mashing user coalesces into one. The panel shows a "restarting…" micro-state throughout. |

### Why not a `willSpawn` callback into a stateless `AddonRunner`

Considered: keep `AddonRunner.run()` blocking, add `willSpawn: (Process) -> Void`. Rejected — it does not fit `job` (needs the handle live *during* a long run) and would not extend to `session` later. The runner is restructured instead (§4).

## 4. `AddonRunner` — spawn / wait split

`AddonRunner.run()` today is synchronous: build `Process`, `run()`, block on `DispatchGroup.wait(timeout:)`, return `RunResponse`. The `Process` never escapes; `AppModel` wraps the whole thing in `Task.detached`. That "sync blocking wrapped in an uncancellable detached Task" is precisely what makes leave-cancellation impossible.

### Locked decisions

| Topic | Decision |
|---|---|
| New shape | `AddonRunner.spawn(...) -> RunningInvocation`, returning immediately once the child is running and its marker file is written. |
| `RunningInvocation` | `{ process: Process, waitForResponse() async throws -> RunResponse, terminate() }`. Holds and drains the live pipes. |
| `oneshot` | `spawn()` + `await waitForResponse()` under `oneshotHardCeiling`. Behaviour-identical to today from the user's point of view. |
| `job` | `spawn()` + `await waitForResponse()` with no wall-clock cap; a heartbeat watchdog resets on each line of output and SIGKILLs on silence past `jobHeartbeatWindow`; first-output must land within `jobHandshakeWindow`. |
| Follow-ups | `confirm` / `list` / `form` submit re-spawns route through `spawn()` + `waitForResponse()` too — same path as `oneshot`, same host registration for their brief life. Not a separate `Task.detached`. |
| Cancellation | Structured: cancelling the awaiting `Task` calls `RunningInvocation.terminate()` → SIGTERM→`killGrace`→SIGKILL. `Task` cancellation propagates to the OS process. This is how a `oneshot` dies on Esc — the invoke flow owns the awaiting task and cancels it on view-disappear, and the host holds the entry as the backstop + the reaper's cross-check. |
| stdout draining | `waitForResponse()` reads stdout to completion. Pipe buffers never fill for `oneshot` / `job`. (A `session` child with no reader would block on a full pipe — that draining requirement follows `session` to its epic, §11.) |
| SIGTERM→SIGKILL | On any kill: SIGTERM, wait `killGrace`, SIGKILL if `isRunning`. A SIGTERM-ignoring child is force-killed. |
| Location | Stays in `JugnuCore`, stays a struct. `RunningInvocation` is a Core type. The **host** that holds these across calls is App-layer (§3). |

## 5. `daemon` — shell-generated launchd agents

A `daemon` command declares intent; the shell writes and owns the plist.

### Locked decisions

| Topic | Decision |
|---|---|
| Manifest block | `daemon: { program, args?, keep_alive? }` — **command-level only**, one block on each command whose `lifecycle: daemon`. Two `daemon` commands → two labels → two plists, independently bootstrapped / torn-down. No addon-level `daemon` block (each agent needs a unique label). |
| **Trust gate (first-party only, for now)** | `lifecycle: daemon` is honoured **only** for addon ids on a hardcoded first-party allowlist (`keep-awake`, `clipboard-history`, and whatever else first-party migrates). Any other addon declaring `lifecycle: daemon` fails `validate-addon.sh` and fails to load, with a clear message. Rationale: a `daemon` is a `RunAtLoad` + `KeepAlive` launchd agent running arbitrary code that survives quit and reboot — a persistent-execution primitive that must not be handed to unreviewed third-party code. The registry is single-publisher today, so the allowlist costs nothing now. Replacing it with a per-entry "daemon reviewed" registry flag is the deferred third-party-daemon-review work (§10). |
| Plist author | **The shell.** It generates `~/Library/LaunchAgents/<label>.plist` from the declared fields. An addon never ships a `.plist`. |
| Shell-controlled plist contents | `Label`, `ProgramArguments` (`program` resolved relative to the addon root, `+ args`), `RunAtLoad` / `KeepAlive` from `keep_alive` (default `true`), `StandardOutPath` / `StandardErrorPath` under the addon state dir, `EnvironmentVariables` carrying `JUGNU_ORIGIN` + the spawning shell's start-time (§6). |
| Label convention | `com.jugnu.<addon-id>.<command-id>` — one label per `daemon` command; stays in the `com.jugnu.*` namespace the reaper and 0023 cleanup key on. |
| Bootstrap | On enable (and on first install-with-enable, including first-run onboarding): `launchctl bootstrap gui/<uid> <plist>`. Never a lazy self-install from the addon. |
| Teardown | On disable and uninstall: `launchctl bootout` + remove the plist. The manifest's `cleanup.launchd` is auto-populated from the `daemon` block. |
| Not tracked by the host | A `daemon` never appears in `AddonProcessHost`. Its lifetime is enable→disable, OS-managed. |

### Rejected

- **Addon-shipped plists** (shell just `bootstrap`s them). An addon-authored `.plist` is an arbitrary-`ProgramArguments`, `RunAtLoad`-trick attack surface not covered by "the manifest is the trust boundary."
- **Shipping `lifecycle: daemon` open to any catalog addon before a review process exists.** See the trust gate.

## 6. The orphan reaper — marker files

The host (§3) is precise but only knows about *this shell's* current children, and only after spawn→register completes. A crashed shell, a `disown`ed grandchild, a child spawned in the non-atomic window — none are recoverable from host memory. A crash-durable, privilege-free backstop catches them.

### Locked decisions

| Topic | Decision |
|---|---|
| Every spawn writes a marker | On `AddonRunner.spawn()`, before returning: write `~/.local/share/jugnu/state/run/<pid>.json` = `{ origin: "<addon-id>:<command-id>:<invoke-uuid>", class, shell_pid, shell_start_ts, spawned_at }`. The `clock` helper writes one marker on `ClockHost.start()` (`origin: "jugnu:clock"`), deletes it on `stop()`. Shell-generated `daemon` plists carry the same fields as env vars (a `daemon` has no marker — it is launchd-owned — but the reaper can still attribute it via `com.jugnu.*` + env). |
| Marker deleted | In the child's `terminationHandler`. A hard SIGKILL of the shell leaves stale markers — the reaper must tolerate "marker exists, pid dead or reused". |
| `JUGNU_ORIGIN` env still stamped | On every spawn and in every `daemon` plist — a free secondary tag that helps `ps` / Activity Monitor debugging. The reaper does **not** depend on reading it back. |
| Reaper reads the directory | Enumerate `state/run/*.json`. For each: the target pid is an orphan to kill iff — the pid is alive, **and** it carries a `JUGNU_ORIGIN`-consistent identity (best-effort; the marker is the authority), **and** no live process matches *both* `shell_pid` **and** `shell_start_ts` with comm name `Jugnu` (PID reuse cannot spoof the start-time), **and** it is not a live entry the host currently owns. |
| Reaper triggers | **Launch** (after the safe-mode check, before the command index builds), **wake** (`didWakeNotification`), **pre-quit**. No periodic sweep. |
| Reaper cost | Read a small directory + a few `kill(pid, 0)` / comm-name checks. Sub-millisecond to low-ms, only ever on launch / wake / quit — never the invoke hot path. |
| Degraded mode (safe mode) | Kill every marker's pid that is alive and whose `(shell_pid, shell_start_ts)` has no matching live Jugnu shell — **without** a manifest class lookup (manifests are not trusted in safe mode, §8). Coarser, still safe: a genuinely-orphaned `daemon`-spawned child has no marker, so degraded mode leans on the §8 blanket `com.jugnu.*` bootout for those. |
| Stale-marker hygiene | A marker whose pid is dead (or reused by a non-Jugnu process) is deleted on sight. |
| Relationship to the host | Two layers. Host = fast, in-memory, real-time kill on Esc / leave, keyed by command. Reaper = crash-durable, directory-based, catches escapees. Neither replaces the other. |
| Field-diagnostic log | Every reap writes one line to `~/.local/share/jugnu/state/lifecycle.log` (`{ event: "reap", origin, reason, ts }`), **all build configs**, capped (last ~200 lines). Safe-mode trips write here too (§8). This is the interim sink; ticket 0019 subsumes this file and adds the rest of the taxonomy. |

### `disown` in addon entrypoints

The **reaper is the defense** against leaked background work — a `disown`ed subshell inherits nothing it needs, and its parent shell's `(pid, start_ts)` is dead, so the reaper kills it on next launch / wake. `scripts/validate-addon.sh` additionally **warns** on `disown` / `nohup` / trailing `&` in entrypoints — this is a **lint nudge for honest mistakes, not a security boundary** (trivially evaded by `eval`, a helper binary, etc.). Deferred work belongs in a `daemon` or the `clock` helper.

## 7. Re-invoke — `on_reinvoke`

| Topic | Decision |
|---|---|
| Field | `on_reinvoke: reuse | replace`, command-level. |
| Default | `reuse` (never silently kills in-progress work). |
| Read for | `job` only (and `session` later). `oneshot` always spawns fresh; `daemon` is always `reuse` (message the running agent / bootstrap if down). |
| `job` + `reuse` | Block the second spawn; bring the running job's progress UI forward (indeterminate spinner + Cancel, §2). |
| `job` + `replace` | SIGKILL the running child immediately; wait ≤ `replaceDeathCeiling` for confirmed death; spawn fresh, or surface "still stopping — try again" and do not spawn. |
| Enforcement | `AddonProcessHost`'s `(addon-id, command-id)`-keyed entries. Re-invoke → look up a live entry of the same class → apply the rule. |
| Debounce | Palette invoke is debounced like `PaletteView` search (§9) — rapid repeat-invokes of the same command coalesce. |
| **Constraint for the future context-aware design** | A context-triggered / programmatic invoke (vision item 5 — the shell fires a command from what is on screen / clipboard, not a keypress) that collides with a running instance must behave as `reuse` **regardless of the field**. `replace` means "replace on explicit user re-invoke." This constraint is also recorded in the UI-speed spec §7 so a future context designer sees it. |

## 8. Crash-loop safe mode

A launch-attempt counter, incremented before risky startup work, cleared once the shell reaches idle-ready.

### Locked decisions

| Topic | Decision |
|---|---|
| "Clean launch" (clears the counter) | The menu bar item mounts, the hotkey registers, and the first `AppModel.bootstrap()` returns without throwing — **idle-ready**. A failure after that (mid-invoke, hours later) is not a launch failure. |
| Counter file | A dedicated tiny file under `~/.local/share/jugnu/state/`. **Not** in `JugnuState` or `jugnu.yaml` — both are parsed at startup and are themselves suspect. A config reset must not wipe it. |
| Counter cannot become a failure mode | Written atomically (temp + rename). Any read failure (missing, garbage, unreadable) → treated as **zero** and normal launch proceeds. A recovery mechanism must not be able to strangle the app. |
| Trip condition | **3 consecutive launches where the counter was incremented but never cleared** — i.e. the launch started risky work and never reached idle-ready. **Crash and hang count identically** (a hung startup the user force-quits is as fatal as a SIGSEGV). The "within N seconds" clause is dropped — how the launch failed does not matter. A single clean launch resets the count, so a one-off (slept mid-launch, one force-quit) self-heals. |
| Optional hardening (phase 4 note, not committed) | If hangs prove common in the field, add a startup watchdog: idle-ready not reached within ~20 s → the app self-terminates and that counts as a strike. Adds startup complexity; only build it if the data says so. |
| Safe mode state | Menu-bar-only. **Zero addons loaded** (any class). Default theme forced. Config loaded defensively; a parse failure routes into the recovery surface. |
| **Safe-mode entry boots out all `com.jugnu.*` agents** | Not just the recovery action — *on entry*. A misbehaving `daemon` launchd agent runs independently of the shell; skipping addon *loading* would not stop it. Safe mode must isolate the app from everything that could be breaking it. A subsequent normal launch re-bootstraps enabled daemons as part of startup. |
| Recovery surface (shared with 0034 malformed-yaml) | Actions: (1) **Reset config to defaults**, (2) **Open config file**, (3) **Disable all addons**, (4) **Try normal launch again**. It is a bisect surface — config vs addon — since the shell does not know which caused the loop. (Agents are already booted out on entry, so "disable all + relaunch" is now about *config* and the enable flags.) |
| Reaper in safe mode | Runs, degraded (§6). |
| Malformed `jugnu.yaml` (ticket 0034) | On a YAML **syntax** error at load (not a bad scalar — theme-hex fallback still handles those), block startup and show the recovery surface. |
| Field log | A safe-mode trip writes `{ event: "safe_mode", strike_count, ts }` to `lifecycle.log` (§6), all build configs. |

## 9. Non-addon in-flight work, detached panels, dev workflow

### Locked decisions

| Topic | Decision |
|---|---|
| Shell-side `Task`s tied to a view | `PaletteView` search-debounce `Task` and `BrowseCatalogView` install `Task` are cancelled on that view's disappearance — a view-owned structured `Task` (`.task` modifier or equivalent), auto-cancelled. No stale results writing into a dismissed or navigated-away panel. |
| `oneshot` cancellation path | The invoke flow owns the `Task` that `await`s `waitForResponse()`; view-disappear / Esc / click-outside cancels it → `RunningInvocation.terminate()`. The host entry + marker are the backstop and the reaper's cross-check. Both paths are exercised by the phase-2 "hide leaves no `Process`" test. |
| Monitor / retain-cycle cleanup | `NSEvent` monitors and `Task` closures in the lifecycle code get `[weak self]` hygiene and explicit teardown, as part of the rewrite. |
| Detached addon-response panels (`card`, `note`) | Dismissed on quit and on sleep by `ShellHost`, the same as any open panel. The process that produced them has already exited — this is view teardown, not process teardown. (A future `session` panel is a detached panel *with* a live process; its teardown is `host.killTracked` + panel close, designed in the `session` epic, §11.) |
| Open-panel disable (ticket 0032 slice) | Before `lifecycle.setEnabled(id:, false)` / uninstall, if `AddonProcessHost.hasTracked` for any of that addon's commands, show an accept / reject alert. Accept → kill + proceed. Reject → cancel. 0032's uninstall-specific concerns + pairing with 0024 stay on 0032. |
| `make stop` runs the real quit teardown | Sends SIGTERM (bounded wait, then SIGKILL) so `applicationWillTerminate` fires — `host.killAll()` for `job` / `oneshot`. **Daemon agents are left running** (they are OS-managed and survive quit by design, §2). A hard `kill -9` in `make stop` would skip the quit path entirely. A separate `make clean-agents` target does an explicit `com.jugnu.*` bootout when a dev wants a clean slate. |
| Atomic install / cancelled install | **Not this epic.** Belongs with the `AddonInstaller.unzip()` zip-slip debt in the sibling install-integrity epic (§11 / ticket 0058). |
| Lifecycle events are traced | Every kill (edge, `replace`, quit), every reap, every safe-mode trip emits a structured record — ids / timestamps / reason only, never args or payload ([Privacy and trust](../conventions.md#privacy-and-trust)). Reap + safe-mode events go to `lifecycle.log` in **all** build configs (§6, §8); the rest are `#if DEBUG` like `InvokeTrace` until ticket 0019's dev log subsumes the file. |

## 10. Later phases of this epic (deferred, not lost)

Captured so they are not forgotten. Each is a real design pass, gated on a concrete consumer. These stay in **0057**; the `session` class and everything specific to it moves to its own epic (§11).

| Deferred | Why not now | Gated on |
|---|---|---|
| **`job` determinate progress protocol** | The wire format for real progress (%, step labels) over the heartbeat channel, and the determinate progress bar UI. §2 ships the heartbeat (liveness) + indeterminate spinner + Cancel now; this adds the real bar. | First `job` addon with meaningful progress (a large file conversion, a scan). |
| **Full `daemon` authoring surface** | Complete manifest schema for `daemon` addons, plist-generation edge cases, crash-restart policy beyond `KeepAlive`. §5 locks the mechanism + first-party gate; the general authoring spec is separate. | First first-party `daemon` addon beyond the migration. |
| **Third-party `daemon` review → registry flag** | Replace the §5 hardcoded first-party allowlist with a per-entry "daemon reviewed" flag set by a review process. | The open registry (tickets 0025 / 0031) approaching. |
| **Startup watchdog** (self-terminate on hang) | §8 trips on 3 incremented-not-cleared launches, which already catches hangs the user force-quits. A watchdog would catch a hang without user action. | Field data showing startup hangs are common. |

## 11. Sibling epics

### `session` lifecycle class — its own epic (new)

`session` — a live process bound to an open detached panel, exchanging messages while the panel is up — is **cut from 0057** and gets its own epic. Reason: the class is only real with bidirectional IPC, and shipping a class nothing can use is the speculative abstraction [conventions](../conventions.md) forbids. Its epic owns:

- the class definition + kill rules (killed on panel-leave / Esc, killed on quit silently, **sleep = leave** — tear down, re-invoke on wake);
- `on_reinvoke: reuse` = focus the open panel (never a second process); `replace` = end + restart;
- the **bidirectional IPC protocol** — newline-delimited JSON over the persistent pipes, addon-initiated frames, a shell read-loop, `api: 2`;
- **stdout draining** even before the read-loop exists, or the liveness check misfires;
- a **SIGTERM "you are about to be killed" flush hook** so a well-behaved `session` can persist state before the grace window (interacts with `killGrace` timing);
- **multi-panel window management** — z-order, focus stealing, per-panel vs shell-global click-outside, multi-display placement, "which panel does Esc close" — once several detached session panels can be open alongside the palette;
- **session-UI teardown on quit / sleep** = `host.killTracked` (process) + panel close.

Gated on the first `session`-shaped addon — most of the Play category (`chess-clock`, `breathing`, `reaction-time`, `memory`) is session-shaped. `tic-tac-toe` stays a re-invoke-per-move `oneshot` on `canvas` and does **not** need this epic.

### Addon install & upgrade integrity — stub epic (ticket 0058)

`AddonInstaller.unzip()` zip-slip · atomic install (unzip→temp, verify, atomic rename, cleanup-on-failure / cancel) · cancelled-install recovery · upgrade-in-place (0018) · dependency install ordering + partial-failure rollback (0025) · namespaced ids + collision resolution (0031) · universal-binary check (0029) · `minShellVersion` check (0043). Not designed here.

## 12. Work items

### Phase 1 — runner seam + host + marker files (no behaviour change)

1. `AddonRunner.spawn(...) -> RunningInvocation` (`process`, `waitForResponse()` with stdout drain, `terminate()`) in `JugnuCore`; writes the `state/run/<pid>.json` marker before returning; `terminationHandler` deletes it.
2. `AddonProcessHost` in the App target, `AppDelegate`-owned, keyed by `(addon-id, command-id)`, value a list of entries; `killTracked` / `killAll` / `hasTracked` / `tracked`.
3. `AppModel.runInvocation` rewired: register after `spawn()`, deregister in `terminationHandler`. `oneshot` = `spawn()` + `await waitForResponse()` under `oneshotHardCeiling`. Both the initial-invoke closure and the follow-up closure use this path — no `Task.detached`.
4. `LatencyBudgets`: `oneshotHardCeiling`, `jobHandshakeWindow`, `jobHeartbeatWindow`, `killGrace`, `replaceDeathCeiling`.
5. `lifecycle.log` writer (capped, all build configs) + the `LifecycleEvent` record; wired to `#if DEBUG` trace for non-reap / non-safe-mode events.
6. Tests (Core, real processes + fixture misbehaving scripts): `spawn()` returns a live handle; `waitForResponse()` resolves + drains stdout; cancel → child dead within `killGrace`; SIGTERM-ignorer → SIGKILL; marker written on spawn, deleted on exit. Tests (App): host register / deregister, per-command keying, follow-up spawn is tracked.
   *Ships green; nothing user-visible changes.*

### Phase 2 — kill on every edge

1. `handleEsc` / `handleClickOutside` / `popTop` → cancel the awaiting `Task` (→ `terminate()`) and `host.killTracked(key:)`.
2. `applicationWillTerminate` + the quit menu item → prompt if any `job` is in flight, then `host.killAll()` (parallel, one `killGrace`, no per-child await).
3. `NSWorkspace.willSleepNotification` → tear down every tracked `job` (and `oneshot` mid-flight); dismiss open `card` / `note` panels.
4. `ShellHost`: dismiss detached `card` / `note` panels on quit and sleep.
5. View-owned `Task` cancel-on-disappear (`PaletteView` search, `BrowseCatalogView` install) + monitor / retain-cycle cleanup.
6. Palette invoke debounce (reuse the search-debounce pattern).
7. `make stop`: SIGTERM + bounded wait (not `kill -9`); add `make clean-agents`.
8. Tests: **"hide leaves no `Process` running"** (the ticket-0014 canary) — automated, covering `oneshot`; quit `killAll` is parallel and bounded; sleep tears down a mid-flight `job`.

### Phase 3 — class model (`oneshot` / `job` / `daemon`)

1. Manifest: `lifecycle` (command + addon-root default; enum open, `session` rejected at load), `on_reinvoke`, `timeout`, command-level `daemon` block. `AddonManifest` parsing + models.
2. `scripts/validate-addon.sh`: class enum; `lifecycle: daemon` only for first-party-allowlisted ids; every `daemon` command carries its own `daemon` block; `timeout` ≤ `oneshotHardCeiling`; `disown` / `nohup` / trailing `&` **warning**.
3. `job` handling: `jobHandshakeWindow` first-output check, `jobHeartbeatWindow` watchdog (SIGKILL on silence), indeterminate-progress + Cancel chrome, "still working — longer than usual" after ~60 s, no wall-clock cap.
4. `on_reinvoke` for `job`: `reuse` brings progress forward; `replace` = immediate SIGKILL + wait ≤ `replaceDeathCeiling` + spawn-or-"still stopping".
5. `daemon`: first-party trust-gate check; shell-generated plists (one per `daemon` command); bootstrap on enable (first-run included), bootout + remove on disable / uninstall; `cleanup.launchd` auto-populated.
6. Open-panel disable alert (ticket 0032 slice): `hasTracked` → accept / reject before `setEnabled(false)` / uninstall.
7. `docs/addon-manifest.md`: document all new fields + the 3-class table + the reserved `session` value.
8. UI-speed spec §7: add the context-invoke `reuse`-on-collision cross-reference.

### Phase 4 — reaper + crash-loop

1. `JUGNU_ORIGIN` + shell-start-ts stamping — `AddonRunner` env, `clock` helper, generated `daemon` plists.
2. Reaper: read `state/run/*.json`; normal + degraded kill authority (`(shell_pid, shell_start_ts)` + comm-name cross-check, PID-reuse-safe); launch / wake / pre-quit triggers; stale-marker hygiene; `lifecycle.log` per reap.
3. Crash-loop counter (dedicated state file, atomic write, read-failure-is-zero, injected clock): increment before risky work, clear at idle-ready, **3 consecutive incremented-not-cleared** trip (crash and hang identical).
4. Safe-mode entry: menu-bar-only, zero addons, forced default theme, **bootout every `com.jugnu.*` agent on entry**, recovery surface; reaper degraded; `lifecycle.log` per trip.
5. Ticket 0034: block startup on `jugnu.yaml` **syntax** error, route into the recovery surface.
6. Tests: counter logic incl. corrupt-counter → normal launch and hang → trip; safe-mode surface renders + agents booted on entry; reaper directory parse + both kill paths + PID-reuse case (fixture markers + fixture processes).

### Phase 5 — migrate the first consumers

1. `pomodoro` → `clock` helper for the deferred chime; drop `( sleep … ) & disown`.
2. `keep-awake` → `lifecycle: daemon` + `daemon` block (first-party allowlisted); delete the hand-rolled plist / `launchctl` code from `bin/run`.
3. `clipboard-history` → `lifecycle: daemon` + `daemon` block (first-party allowlisted); delete the hand-rolled `ensure_watcher`.
4. Verify the **first-run** path bootstraps `clipboard-history`'s daemon through the on-enable bootstrap — no lazy self-install.
5. Update each addon's test suite.

### Manual (shell-smoke.md)

1. Real sleep/wake tears down a mid-flight `job`; reaper kills a real orphaned `disown`ed child after a simulated shell crash (kill -9 the shell, relaunch, confirm the marker + the child are gone); `make stop` leaves no tracked child but **leaves** daemon agents; safe-mode entry boots out `com.jugnu.*` agents; a `job` that stops heartbeating is SIGKILLed within `jobHeartbeatWindow`.
