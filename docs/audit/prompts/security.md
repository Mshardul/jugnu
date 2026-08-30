# Security audit

## How to run

Fresh agent session. Read this whole file. Work the checklist as todos. Write the
report to `docs/audit/report/pending/YYYY-MM-DD-security.md` from
`docs/audit/report/_template.md`. **First check `report/pending/` — if a
`*-security.md` already sits there, stop and tell the user.** After writing the
report, update this prompt's row in [`README.md`](README.md) — Last run = today,
Last severity = the worst finding.

## POV

Trust boundaries and hostile input. Jugnu downloads addons and helpers over the
network, unpacks archives, spawns processes, and installs launchd agents — every
one of those is an attack surface. Audit them as if an addon zip, a registry
response, or a `jugnu.yaml` were written by an attacker.

## Scope — in

Concern-defined. Inspect these regardless of directory:

- **Install / unpack**
  - `shell/Sources/JugnuCore/AddonInstaller.swift`
  - `scripts/package-addon.sh`, `scripts/package-helper-clock.sh`,
    `scripts/validate-addon.sh`, `scripts/build-registry.sh`
- **Process spawning / runtime**
  - `shell/Sources/JugnuCore/AddonRunner.swift`
  - `shell/Sources/JugnuCore/Protocol/RunJSON.swift`,
    `shell/Sources/JugnuCore/Protocol/RunModels.swift`
  - `shell/Sources/JugnuUI/CommandInvoke.swift`
  - every `addons/*/bin/run`, `addons/*/bin/watch`, `addons/nudges/bin/nudges.js`
- **Registry / helper trust**
  - `shell/Sources/JugnuCore/RegistryClient.swift`,
    `shell/Sources/JugnuCore/RegistryCache.swift`
  - `shell/Sources/JugnuCore/ManifestLoader.swift`
  - helper install/run code — `ClockHost.swift`, `ClockClient.swift`, and grep
    `helper` / `Helper` across `JugnuCore` for the download-once-and-reuse path
  - `registry/addons.json`, `registry/helpers.json`, `registry/README.md`,
    `helpers/clock/helper.yaml`
- **launchd / cleanup / background agents**
  - `shell/Sources/JugnuCore/Cleanup.swift`
  - anything writing to `~/Library/LaunchAgents` (grep `LaunchAgents`, `launchctl`,
    `bootstrap`, `bootout` across `shell/`)
  - `addons/clipboard-history/bin/watch` and its plist handling
- **Config / path handling**
  - `shell/Sources/JugnuCore/Paths.swift`, `ConfigStore.swift`, `StateStore.swift`
  - YAML parsing paths (grep `Yams`, `yaml` across `shell/`)
  - env overrides — **re-derive the live set at audit time**: grep
    `ProcessInfo.processInfo.environment` and `environment[` across
    `shell/Sources/`, plus `JUGNU_` across the repo. As of this writing the
    code-referenced set is `JUGNU_ADDON_PATH`, `JUGNU_REPO_ADDONS`,
    `JUGNU_HELPER_CLOCK` (derived from a helper ref), `JUGNU_SCREENSHOT_MODE`.
    `JUGNU_HELPER_PLAY_RUNTIME` appears in tests only (a fixture helper id).
    `JUGNU_STATE_DIR` / `JUGNU_CONFIG_DIR` / `JUGNU_LOG_FD` are named in the
    2026-08-27 spec but not yet in code — treat their *appearance* as a signal
    the state/config work has started.
- **Addon state dir + config passthrough**
  (`docs/architecture/2026-08-27-addon-state-and-config-design.md`)
  — **spec locked, implementation pending.** As of this writing `AddonRunner`
  sets no `JUGNU_STATE_DIR` / `JUGNU_CONFIG_DIR`, `AddonManifest` has no
  `config:` field, and nothing wires `StateStore` into install/invoke. The
  finding here is *whether code has started building this and diverged from the
  locked-decisions table*, or whether an `addon.yaml` already ships a `config:`
  block the shell can't read. If/when it lands, check:
  - the shell creates `~/.local/share/jugnu/state/<id>/` and hands `JUGNU_STATE_DIR`
    on every invoke — where is it created, torn down, and can `<id>` escape the root?
  - per-addon config `~/.config/jugnu/addons/<id>.yaml`, validated against the
    `config:` schema in the sha256-verified zip — a new hostile-YAML surface, and
    a new place resolved values flow into a run request
- **Screenshot automation**
  - `shell/App/ScreenshotMode.swift`, `shell/ScreenshotTests/`, `JUGNU_SCREENSHOT_MODE`
    — does the mode bypass any install/verify/permission gate?
- **Signing / distribution**
  - `.github/workflows/release-addons.yml`, `.github/workflows/ci.yml`
  - the CI `semgrep` job (`p/security-audit`, `p/python`) — what it covers, what it
    doesn't (it scans `addons/` only, not `shell/`)
  - `SECURITY.md`, `PRIVACY.md`, `docs/release-process.md`

## Scope — out

- `.venv/`, `.build/`, `shell/DerivedData/`, `shell/.build/`, `dist/`, `__pycache__/`
- Pure UI look/layout (that's `code-quality` / design work)
- Test files, except to note a missing security test as a Minor finding
- Third-party checked-out deps (Yams, HotKey) — note version currency only

## Ground truth

- `docs/architecture/2026-08-22-shell-design.md` — the trust model, sha256 story,
  stated v0 non-goals (code signing, sandboxing)
- `docs/architecture/2026-08-26-permissions-privacy-security-design.md`
- `docs/architecture/2026-08-27-addon-state-and-config-design.md` — the state-dir /
  config-passthrough contract (locked decisions table)
- `docs/architecture/2026-08-25-nudges-clock-helper-design.md` — helper download /
  reuse / trust model
- `docs/conventions.md` → **Privacy and trust** — the hard constraints
- `docs/addon-manifest.md` — what a manifest is allowed to declare
- `PRIVACY.md`, `SECURITY.md`

A v0 non-goal that is *documented* as such is at most **Major**, and only if it's
now exploitable in practice or the risk grew. An undocumented gap is **Critical**.

## Existing tickets in this domain

The known seed for this lens: zip-slip / path traversal in `AddonInstaller.unzip()`
(`shell/Sources/JugnuCore/AddonInstaller.swift`) — shells to `/usr/bin/unzip` with
no path-traversal guard on extracted entries; also `AddonRunner` process-spawning
safety and the sha256-only (no code signing) registry trust model, a documented
v0 non-goal. Report these even though they are known — this audit's findings are
what become tickets.

Cross-check against `docs/tickets.md` (**re-check status at audit time — these
move**): **0021** (per-addon sandboxing), **0022** (TCC reset detection),
**0023** (disable stops background agents — **marked Done 2026-08-29**; verify
the fix held and check the re-enable residual its Remarks flag as not-fixed:
`bin/run`'s lazy `ensure_watcher`), **0024** (full uninstall cleanup), **0026**
(single-process enforce — `SingleInstance.swift` exists but is app-level, not
the per-addon invoke guard 0026 asks for), **0035** (`JUGNU_ADDON_PATH`
visible), **0038** (permission disclosure pre-install), **0041** (no orphan
processes on sleep), **0044** (kill in-flight on quit), **0054**
(permissions/privacy/security epic).

Report findings even when covered — tag `covered by 00XX` — so a stale or
too-narrow ticket surfaces.

## What to check

1. **Archive extraction.** `AddonInstaller.swift` `unzip()` (currently
   `:210-221`) shells `/usr/bin/unzip -q <zip> -d <dest>` — argv, not a shell
   string (good), but no entry-count cap, no size cap, and `unzip` follows
   symlinks in the archive. Does *any* code path guard extracted entries
   against `../` / absolute paths / symlink escape (zip-slip)? Where does it
   extract to (`temporaryDirectory/jugnu-extract-<UUID>`), and is `findAddonRoot`
   walking that safely?
2. **sha256 verification.** Is the hash checked *before* anything from the
   archive is written, executed, or trusted? **What happens when the expected
   hash is absent** — `installFromLocalZip` / `installHelperFromLocalZip` do
   `if let expected = expectedSHA256?.lowercased(), !expected.isEmpty` and
   **skip verification entirely on nil/empty**. Can a registry entry carry an
   empty `sha256`? Is the expected hash fetched over a channel an attacker
   can't swap (plain HTTPS? redirects followed?)? On mismatch — hard fail
   (currently yes) or warn?
3. **Registry response handling.** Is `registry/addons.json` / `helpers.json`
   parsed defensively — unknown fields, huge fields, hostile URLs (file://,
   localhost, redirects)? Can a registry entry point a download at an arbitrary
   host or path? **`URLSession.shared.download(from:)` (`AddonInstaller.swift:17,
   148`) follows HTTP redirects by default** — a registry URL on a trusted host
   that 302s to `file://` or an attacker host. Chained with §2's absent-hash
   gap this is a full trusted-install bypass.
4. **Process spawning.** Every `Process` / `posix_spawn` / shell-out: are
   arguments passed as an argv array (not a shell string)? Any interpolation of
   addon-controlled or clipboard-controlled data into a command line?
   **Child environment: `AddonRunner.swift:85` does
   `var env = ProcessInfo.processInfo.environment` then overlays helper vars —
   the addon inherits Jugnu's *entire* environment** (`JUGNU_ADDON_PATH`,
   `JUGNU_REPO_ADDONS`, the user's `PATH`, any token in the parent env). See
   "what to flag".
5. **Addon privilege.** Every addon runs with full host privilege today (known —
   0021). Beyond that: does anything an addon emits on stdout get eval'd,
   path-joined, or written to disk without validation? Check `RunJSON` /
   `RunModels` parsing.
6. **launchd agents.** Who can cause a plist to be written to
   `~/Library/LaunchAgents`? Is the label namespaced and validated? On disable /
   uninstall, is the plist removed *and* the job booted out *and* verified gone
   (0023 found it wasn't)? Can an addon name its plist to collide with another's?
7. **Path handling.** `Paths.swift` — are the canonical dirs
   (`~/.config/jugnu`, `~/.local/share/jugnu`, `~/.local/share/jugnu/addons`,
   `~/.local/share/jugnu/state/<id>`) constructed safely? Any `String` path
   concatenation with an addon id (`state/<id>/`, `addons/<id>.yaml`) that isn't
   validated as a safe single path component?
8. **Env overrides.** `JUGNU_ADDON_PATH` skips verification entirely. Is that
   gated to debug builds or at least visibly flagged (0035)? Walk every var in
   the re-derived live set (grep first, see Scope) — as of now
   `JUGNU_REPO_ADDONS`, `JUGNU_HELPER_CLOCK`, `JUGNU_SCREENSHOT_MODE` — does any
   weaken a check, redirect a download, or relocate a trusted dir without a
   visible signal?
9. **YAML config.** The global `~/.config/jugnu/jugnu.yaml` is live
   (shell/theme/addon-enable list — `ConfigStore` / `Models.swift`). The
   per-addon `~/.config/jugnu/addons/<id>.yaml` is **2026-08-27 spec, not
   built** (no `config:` field in `AddonManifest`). For the global file —
   billion-laughs / deep-nesting protection? Does a bad value fall back safely
   (theme hex does; what else)? Can YAML set a path, command, or URL that's then
   used unsanitized? For the per-addon file — flag it only if code has started
   building it; check the validation-against-schema story then.
10. **CI / release.** Does `release-addons.yml` compute and publish the sha256 the
    client will check? Is the registry JSON generated from the same artifacts
    that get uploaded? Any step where a compromised CI could ship an addon the
    client would trust? Is anything signed / notarized (still a documented v0
    non-goal — flag only if the risk changed)? Note what the `semgrep` CI job
    does and does not cover: it scans `addons/` only (not `shell/`), configs
    `p/security-audit` + `p/python`, **and explicitly `--exclude-rule`s
    `python-logger-credential-disclosure`** (`ci.yml:52-54`) — a credential-leak
    rule is off.
11. **Addon `bin/` scripts.** Skim each `addons/*/bin/run` (19 addon dirs: 15
    registry-shipped + 3 `ui-demo-*` + `window-layouts`; bash, plus
    `brew-outdated` in JXA) and `addons/clipboard-history/bin/watch` for: shelling
    out with unquoted `$1` / clipboard content, `curl | sh`, writing outside the
    addon's own state dir (`$JUGNU_STATE_DIR`), requesting more permission than the
    job needs, an `eval` on anything from stdin or the run request.
12. **Secrets.** Grep for tokens, keys, `.env` contents committed. Check
    `.env.example` only documents, never contains, real values.

## What to flag

- Any unsanitized path from an archive entry, registry field, manifest, or config
  reaching a filesystem write or `Process` — **Critical**.
- Any code execution or file write that happens *before* sha256 verification —
  **Critical**.
- A launchd plist that survives disable/uninstall, or a collidable label —
  **Critical** (privacy: a watcher keeps running).
- Clipboard content or command args interpolated into a shell string — **Critical**.
- An absent / empty `sha256` on a registry entry causing an install to proceed
  unverified — **Critical**.
- A redirect from a trusted registry/download host to `file://` or another host
  being followed — **Major**, **Critical** if chained with an unverified install.
- Child process inheriting the full parent environment — **Major**; escalate to
  **Critical** if a specific inherited var (a token, `JUGNU_ADDON_PATH`) is
  reachable by addon code in a way that weakens a trust boundary.
- A documented v0 non-goal (signing, sandboxing) that has become exploitable in
  practice, or where the addon count / trust surface has grown enough to change
  the risk calculus — **Major**.
- Missing size/count caps on extraction or registry parsing — **Major**.
- Env override that weakens verification without a visible signal — **Major**.
- Missing defensive parsing (unknown-field, depth, size) on external JSON/YAML —
  **Minor** unless a concrete exploit path exists.
- Missing security regression test for a check that exists — **Minor**.

## What NOT to flag

- Per-addon sandboxing as a *new* idea — it's 0021, note under "covered" and move on.
- Absence of code signing as a surprise — it's a documented non-goal and 0017;
  only flag if the *risk* changed, not the fact.
- Style, naming, dead code — that's `code-quality`.
- Anything in `.venv/`, `.build/`, `DerivedData/`, `dist/`.
