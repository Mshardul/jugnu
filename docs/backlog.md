# Jugnu backlog

Unbuilt jobs live in the packaging map and gap list below. Shipped first-party sources live under `addons/`.

**Command + UI inventories (living):** [catalog-commands.md](catalog-commands.md) · [catalog-ui.md](catalog-ui.md). Prefer those for “what exists / what’s planned” from a command or panel POV; this file keeps packaging rationale and gap notes.

## Platform (build order)

| Priority | Item | Notes |
|---|---|---|
| 1 | Shell + YAML addon enablement | Design before scaffold — see `docs/architecture/` |
| 2 | Dual clipboard modes | Ephemeral vs history; privacy-aware; build on `addons/clipboard-history` |
| 3 | Robust window management | First-party `window-layouts` — [spec](architecture/2026-08-24-window-layouts.md) · [ticket 0046](tickets.md) **done** |
| 4 | Addon **popup UI** host | [UI + speed design](architecture/2026-08-22-addon-ui-speed-design.md) (Approved) · [P1 plan](superpowers/plans/2026-08-22-addon-ui-host-p1.md) **done** |
| 5 | **Speed** budget | Invoke → visible result; budgets in that design §6 |
| 6 | Context-aware UI (later) | Reserved in UI + speed §7 — after UI host exists |
| 7 | Palette + addon UI **product pass** | [2026-08-23 spec](architecture/2026-08-23-palette-ui-product-pass.md) · [plan](superpowers/plans/2026-08-23-palette-ui-product-pass.md) — search quality, AppKit→SwiftUI panel rewrite onto shared design tokens, user-editable light/dark theming, keyboard/motion accessibility, first-run recommended-set refresh, live-verification suite. **Implemented; walk [shell-smoke.md](architecture/shell-smoke.md)** |
| 8 | Persistent latency logging (future epic) | [Ticket 0001](tickets.md) — JSON-lines, capped retention, timing/ids only, never payload |
| 9 | Addon management / settings (future epic) | [Ticket 0002](tickets.md) taxonomy/install. Chrome: [0008](tickets.md) **done** ([one panel, presets, stack](architecture/2026-08-23-shell-surface-presets.md)). Slices [0005](tickets.md), [0009](tickets.md), [0011](tickets.md) done; [0006](tickets.md), [0007](tickets.md), [0010](tickets.md), [0012](tickets.md) still open — walk [shell-smoke.md](architecture/shell-smoke.md) manual section before closing further |
| 10 | Security audit (recurring) | Not a ticket — a POV audit lens: [`docs/audit/prompts/security.md`](audit/prompts/security.md). Known seed: zip-slip in `AddonInstaller.unzip()`; expect more from a full installer/runner/registry-trust pass. Findings become tickets after a run. |
| 11 | ~~Addon process lifecycle + crash recovery (epic)~~ | **Done 2026-09-04** — [Ticket 0057](tickets.md) · [2026-08-30 spec](architecture/2026-08-30-addon-process-lifecycle-design.md) · [plan](superpowers/plans/2026-08-30-addon-process-lifecycle.md). Phases 1–5 shipped. Spec §10 deferred items stay in the spec. Absorbed [0014](tickets.md) [0026](tickets.md) [0032](tickets.md) [0034](tickets.md) [0036](tickets.md) [0041](tickets.md) [0044](tickets.md). |
| 12 | `session` lifecycle class + addon IPC (epic) | [Ticket 0059](tickets.md) — stub, no design yet. Live process bound to an open panel + bidirectional IPC (`api: 2`). Cut from 0057 (§11); gated on the first `session`-shaped addon (most of Play). |
| 13 | ~~Addon install & upgrade integrity (epic)~~ | **Done 2026-09-06** — [Ticket 0058](tickets.md) · [2026-09-05 spec](architecture/2026-09-05-addon-install-upgrade-integrity-design.md). Phases 1–6 shipped. Walk [shell-smoke.md](architecture/shell-smoke.md) 0058. |
| 14 | Keep current (app + addons + first launch) | [Ticket 0063](tickets.md) · [2026-09-07 spec](architecture/2026-09-07-keep-current-design.md) · [plan](superpowers/plans/2026-09-07-keep-current.md). Unified shell-zip pipeline; keep-app / keep-addons confirms; two-step first-run. Absorbs [0017](tickets.md) [0062](tickets.md) [0004](tickets.md). |

**Canonical product surfaces:** [`docs/vision.md`](vision.md) — commands + popup UI + speed; context-aware surfacing later.

## Gap list (keep / build)

Not yet staged as leaves. Candidates after shell MVP:

1. Audio output switcher
2. ~~Caffeine / keep-awake~~ done → `addons/keep-awake`
3. Webcam mute
4. AirPods / BT battery bar
5. Claude/agent mission control (lite)
6. ~~Dev-server / common-ports bar~~ done → `addons/ports`
7. Screenshot inbox
8. ~~Paste plain / strip formatting~~ done → merged into **clip-tools** (`paste-plain` command) per [0074](tickets.md)
9. Kill hung app picker
10. Disk pressure bar

## Accepted addons (not staged yet)

Accepted for backlog — still **not** scaffolded. Build later.

**Canonical rules:** [`docs/vision.md`](vision.md) — *Catalog hierarchy* (Category → Addon → Commands/UI; **Helper** / **Bundle** are install plumbing), **shared-capability rule**, and **Surfaces** (popup UI + speed; context later).
Ids below are **capability / job ids**; several become **commands and UI** on one **addon** zip. Do not treat every row as its own zip — and do not treat rows as CLI-only. Play ids are the exception: each is its own addon under the Play category.

### Packaging map (preferred addon → commands)

Draft boundaries — refine by user mental model (not “all toggles in one zip”).
**Ids name the job** a user would search for — not the scenario you imagined when inventing them (e.g. mute mic+speakers is `mute-all`, not `call-mute-all`).

**Same-shape rule (accepted hosts):** when a host is accepted, ship the natural sibling commands on that zip (converters, brew ops, image ops, layout ops, pomodoro controls, etc.) — do not require a separate accept line for each micro-variant. Rows below name the family; detail tables list representative ids.

| Category (browse) | Addon (zip) | Commands / capability ids | Why |
|---|---|---|---|
| Appearance | **dark-mode** | toggle / set light / set dark | One addon for appearance mode |
| Appearance | **night-shift** | toggle | Own job |
| Appearance | **true-tone** | toggle | Own display job |
| Appearance | **display-brightness** | presets | Brightness job |
| Appearance | **finder-chrome** | `finder-chrome`, desktop-icons, dock-autohide, menubar-autohide, hidden-files, path-bar, status-bar, restart-finder | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| Appearance | **wallpaper-shuffle** | shuffle from folder | Optional; or under desktop-toggles |
| Appearance | **screensaver** | start now | Small; desktop-toggles or Security |
| Appearance | **hot-corners** | show / open Hot Corners | Thin Settings surface; possible merge with login-items/settings-jump deferred — see [0074](tickets.md) |
| Appearance | **finder-chrome** | see the row above | Same zip as desktop chrome. Not a second addon. |
| Appearance | **resolution-preset** | named resolution / HiDPI presets | Own display job |
| Clipboard | **clip-tools** (`addons/clip-tools`) | slugify, json/csv/yaml/xml-pretty, base64, url-encode/decode, jwt-decode, timestamp, text-stats, uuid, md-link, clip-clear, **case**, **sort-lines**, **dedupe-lines**, **lorem**, **regex-replace**, **hash**, **tabs-spaces**, **invisible-chars**, **markdown-table**, **reverse-lines**, **extract-emails**, **json-path**, **csv-json** (+ yaml↔json, xml→json), **unicode-name**, **iso-week**, line trim/join/split/number, escape/unescape | Phase 1 **shipped** (palette commands). Transform panel = Phase 2. Declares `python-runtime` helper. **paste-plain** merged in per [0074](tickets.md). See [catalog-commands](catalog-commands.md) / [catalog-ui](catalog-ui.md). |
| Clipboard | **clipboard-guard** | detect likely secrets / warn before history storage / clear or redact clipboard | Privacy utility for clipboard workflows; detection is heuristic |
| Clipboard | **diff** | diff-clip | Heavier than one-shot transforms — own addon unless kept tiny on clip-tools |
| Files | **paths** | path-copy, reveal-path, **count-files**, **folder-size** | Path/Finder folder jobs |
| Files | **images** | heic-jpeg, resize-image, **image-rotate**, flip, format convert, compress (+ other `sips`/Image I/O ops) | Image transforms family |
| Files | **folder-clutter** | `folder-clutter`, reveal-downloads, downloads-age, screenshot-inbox, reveal-latest-screenshot, archive-latest-screenshot, archive-older-screenshots, desktop-sweep, large-files | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| Files | **airdrop-folder** | share Finder selection via AirDrop UI | Finder / share QoL |
| Files | **quarantine-clear** | clear Gatekeeper quarantine xattr (± check) | File / Gatekeeper QoL |
| Files | **new-file** | create in front Finder folder | Own file job |
| Files | **zip-selection** | zip Finder selection | Pair with unarchive; shared archive helpers in zips |
| Files | **unarchive** | unzip archive beside it | Pair with zip-selection |
| Files | **archive-utility** | create archives / compression presets / test integrity / reveal archive | Archive workflow; may eventually absorb zip-selection and unarchive |
| Files | **save-clipboard** | clipboard → Scratch/Downloads | May share path helpers w/ scratch-folder |
| Files | **quick-capture** | capture clipboard / append to today / open latest / reveal captures | Intentional clipboard-to-file capture; text first, images later |
| Files | **ocr** | image → text (Vision) | Own; permission-heavy |
| Files | **trash-ui** | trash-selection, empty-trash, **trash-put-back** | Trash jobs on trash-ui |
| Files | **screenshot-folder** | open screenshots location | Own until screenshot-inbox (gap) absorbs it |
| Files | **folder-clutter** | screenshot inbox commands | Same zip as downloads triage. Not a second addon. |
| Files | **pdf-tools** | Page tools on one addon: unlock, merge, split, extract, reorder, rotate, and the rest of the shipped PDF commands. Later, one **Convert** panel for JPG ↔ PDF and PDF → PNG, including Finder **Convert** | Same-shape PDF jobs — not on images |
| Files | **folder-clutter** | large-files | Same zip. Not a second addon. |
| Files | **folder-clutter** | desktop-sweep | Same zip. Not a second addon. |
| Files | **mount-dmg** | mount / unmount selected DMG or volume | Own volume job; possible small-Finder-utility grouping w/ quarantine-clear/airdrop-folder considered and deferred — see [0074](tickets.md) |
| Files | **media-convert** | **afconvert** (+ other built-in audio convert presets) | Audio via macOS `afconvert` |
| Files | **jump-to-location** | `jump-to-location`, favorite-folders, recent-files | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| Files | **jump-to-location** | recent-files | Same zip as favorite folders. Not a second addon. |
| Window | **window-layouts** | center, fill-desktop, maximize, hide-others, pin-top, space-jump, stage-toggle, left/right-half, quarters, gather-windows, move-display, app-windows, desktop-name (Jugnu-local label), fullscreen-toggle, minimize-all, show-desktop, **tile-two** (+ swap / other layout ops); **zones** (save/apply, max 6, replace picker). Fold **layout-save**. **No layout-undo.** Snap board + palette commands. Spec: [2026-08-24 window-layouts](architecture/2026-08-24-window-layouts.md) | One window family |
| Meeting | **screenshare-prep** | hide icons + pause banners; **screenshare-restore** | Orchestrator + one-shot undo |
| Meeting | **mute-all** (`addons/mute-all`) | mute mic+speakers / restore; **mute-status** later (menu glyph) | Merges with `mic-mute` into one **Audio** addon per [0074](tickets.md) — not yet built |
| Meeting | **display-mirror** | mirror vs extend | Own display job |
| Meeting | **focus-until** (or on **focus-toggle**) | Focus for duration / until time | Timed Focus |
| Meeting | **volume-presets** | named output levels | May share audio helpers w/ speaker-mute / audio-output |
| Meeting | **record-screen** | start/stop screen recording | Own; permission-heavy |
| Meeting | **flash-attention** | bounce Dock / flash screen | Physical “hey” — own tiny addon |
| Meeting | **meeting-join** | clipboard URL → join; **meeting-app-pick** | Join + app chooser form |
| Network | **network** | `network`, copy-ip, dns-flush, proxy-toggle, vpn-connect, wifi-toggle, ping, hosts-block, hosts-backup, http-status, http-headers | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. Ports stays separate. |
| Network | **network** | ping | Same zip as hosts. Not a second addon. |
| Network | **ports** | list listeners, kill by pid/port (folds port-scan-local, port-picker, gap common-ports) | `addons/ports` — one surface. Kept separate from the new Network addon: process/port-killing job, not a network-probe job |
| Network | **network** | http-status, http-headers | Same zip. Not a second addon. |
| Dev | **git-root** | reveal git root of front path | Possible merge with repo-jumper considered, deferred pending repo-jumper's own scope — see [0074](tickets.md) |
| Dev | **default-apps** | `default-apps`, default-browser, open-url, open-url-profile | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. Display name: Default Selection. |
| Dev | **brew-outdated** (`addons/brew-outdated`) | brew-services, **brew-cleanup**, doctor/update and other brew ops | One Homebrew job shelf |
| Dev | **repo-jumper** | jump known git repos | Own; possible merge with git-root considered, deferred — see [0074](tickets.md) |
| Dev | **ssh-host-picker** | pick SSH host → connect | Own |
| Dev | **process-find** | process-list, find-by-name, **process-sort** (CPU/mem) (+ force-quit / copy PID variants) | ≠ quit-heavy, ≠ kill-hung — confirmed separate, [0074](tickets.md) |
| Dev | **open-terminal-here** (`addons/open-terminal-here`) | last-picked terminal at Finder folder; **term-app-pick** later | Dev QoL |
| Dev | **app-control** | `app-control`, app-info, relaunch-app | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| Dev | **app-control** | relaunch-app | Same zip as app-info. Not a second addon. |
| System | **notify-clear** | clear Notification Center | Own; private API risk |
| System | **login-items** | list / open Login Items | Possible merge with settings-jump/hot-corners as "System Settings shortcuts" considered, deferred pending settings-jump's own scope — see [0074](tickets.md) |
| System | **power-sleep** | `power-sleep`, keep-awake, stop-keep-awake, keep-awake-status, keep-awake-watch, sleep-now, display-sleep | Command list locked in [catalog-commands](catalog-commands.md). Not scaffolded. Shipped `keep-awake` stays until this zip exists. |
| System | **keep-awake** (`addons/jugnu.keep-awake`) | pick, stop, status, watch | Shipped. Target ids live on **power-sleep** when that addon is built. |
| System | **settings-jump** | palette → System Settings pane | Own; possible merge target for login-items/hot-corners deferred until this addon's own scope is settled — see [0074](tickets.md) |
| System | **default-apps** | default-browser | Same zip as open-url. Not a second addon. |
| System | **memory-pressure** | pressure + top memory apps | Own; pair conceptually w/ disk-pressure gap |
| System | **speak-clip** | speak clipboard / stop | Own a11y job |
| System | **intervals** (`addons/jugnu.intervals`) | manage, nudge-now, pause, resume, restore-presets, advanced, show-card, start-focus, start-break, pomodoro-status, reset-pomodoro, phase-chime; **pomodoro-skip** later | Shipped. Pomodoro is a phases preset on this list. |
| System | **time-machine** | status / start backup / open Time Machine | Own |
| System | **floating-note** (`addons/floating-note`) | `open` (scratchpad, persist on close/quit), **quick-note** (throwaway; close discards), **note-pin** | One note addon: persistent scratchpad vs session scrap; pin is chrome QoL |
| System | **world-clock** (`addons/world-clock`) | + **world-overlap** | Clocks + meeting overlap |
| System | **intervals** | pomodoro-skip | Same zip. Skip/extend stays planned on this addon. |
| Security | **password-gen** | random password; **password-options** (passphrase / PIN / exclude-ambiguous / copy-once / …) | Own — not under play |
| Play | *(each id its own zip)* | dice-roll, coin-flip, pick-one, number-guess, hangman, eight-ball, chess-clock, rps, stopwatch, memory, breathing, reaction-time, tic-tac-toe, fortune | Play is a **category**, not one shelf. Shared RNG/timer code is a **helper** ([0047](tickets.md)) — ship that before any Play zip. **Bundles** later ([0048](tickets.md)); 14 separate catalog rows is fine until then. |
| Design | **sf-symbols** | pick/copy | Solo for now |
| Design | **design-calc** | type-scale, rem-px, **aspect-ratio** (+ spacing-scale and other design math) | Design math shelf |
| Design | **color-eyedropper** | + color-format | Eyedropper + hex/SwiftUI format commands |
| Design | **grid-overlay** | column/baseline overlay | Own design-QA overlay |
| Design | **emoji-picker** | search emoji → copy | Own; keep tiny |
| Design | **qr-clip** | encode + **qr-decode** | QR both directions |
| Tools | **unit-convert** | all units | One converter addon |
| Meeting | **meeting-bar** | next meeting / join lite | Own; or fold into **next-event** |
| *(own addons)* | — | camera-check, quit-heavy, scratch-folder, lock-screen, low-power, reminder-add, next-event, kitchen-timer, flash-attention, process-find, pdf-tools, speak-clip, resolution-preset, settings-jump, memory-pressure, grid-overlay, design-calc, time-machine, emoji-picker, media-convert, mount-dmg, airdrop-folder, quarantine-clear, repo-jumper, ssh-host-picker | Distinct jobs. (Several former entries here now merge elsewhere per [0074](tickets.md): mic-picker/speaker-mute→Audio; copy-ip/dns-flush/proxy-toggle/vpn-connect/wifi-toggle/http-status→Network; large-files/desktop-sweep→folder-clutter addon; finder-toggles→Finder/Desktop chrome; default-browser→Default Selection; app-info/relaunch-app→app-control; favorite-folders→jump-to-location; sleep→Power/Sleep.) |

### Meeting / device

| Id | One-liner | Packaging |
|---|---|---|
| mic-picker | Switch default input device | Folds into **Audio** addon per [0074](tickets.md) — not yet built |
| meeting-join | Clipboard meeting URL → join | Own; **meeting-app-pick** chooses Zoom/Meet/Teams/browser |
| meeting-app-pick | Choose which app opens a meeting URL | **meeting-join** form |
| camera-check | Short camera preview before video | Standalone |
| speaker-mute | Mute/unmute output only | Folds into **Audio** addon per [0074](tickets.md) — not yet built |
| screenshare-prep | Hide desktop icons + pause banners for N min | May call **desktop-toggles** |
| screenshare-restore | One-shot undo for screenshare-prep | **screenshare-prep** |
| mute-all | Mute mic + speakers; restore prior state | Folds into **Audio** addon per [0074](tickets.md) — not yet built |
| mute-status | Real command (not just a passive menu-bar glyph): check current mic/speaker mute state on demand | Folds into **Audio** addon per [0074](tickets.md) — not yet built |
| display-mirror | Mirror vs extend for a chosen display | Own addon |
| focus-until | Focus/DND for N minutes / until a time | Own **or** on **focus-toggle** |
| volume-presets | Jump output volume to named levels | Own; may share helpers w/ speaker-mute |
| record-screen | Start/stop macOS screen recording | Own; permission-heavy |
| flash-attention | Bounce Dock / flash screen so someone at desk notices you | Own tiny addon |

### Devops / network / dev

| Id | One-liner | Packaging |
|---|---|---|
| copy-ip | Copy LAN (optional public) IP | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| dns-flush | Flush DNS cache | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| proxy-toggle | System proxy on/off | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| quit-heavy | Top CPU/mem → quit | Standalone; ≠ kill-hung — confirmed separate from process-find, [0074](tickets.md) |
| vpn-connect | Named VPN connect/disconnect | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| hosts | Enable/disable named `/etc/hosts` blocks | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| hosts-backup | Snapshot `/etc/hosts` before toggle; restore prior snapshot | **network** |
| ping | Ping host from clipboard or typed input | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| port-scan-local | List listening ports on this Mac | Merged into **ports** (`addons/ports`) — stays separate from the new Network addon, [0074](tickets.md) |
| git-root | Reveal git root of front Finder/Terminal path | Possible merge with repo-jumper considered, deferred — see [0074](tickets.md) |
| open-url | Open clipboard URL in a chosen browser | **default-apps** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| open-url-profile | Open URL in a chosen browser *profile* (Chrome/Safari/…) | **default-apps** |
| http-status | HEAD/GET clipboard URL → status + final URL + timing | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| http-headers | Copy response headers / timing (e.g. as markdown) | **network** |
| brew-services | List / start / stop / restart Homebrew services | **brew-outdated** |
| brew-cleanup | `brew cleanup` (± prune) and other brew maintenance ops | **brew-outdated** (w/ doctor/update siblings) |
| process-list | List processes (filterable) → copy PID / reveal / quit | **process-find** |
| process-find | Find processes by name → reveal / quit / copy PID | Own addon; ≠ quit-heavy, ≠ kill-hung |
| process-sort | Sort process list by CPU or memory | **process-find** |
| term-app-pick | Open here in Terminal / iTerm / Warp / … | **open-terminal-here** |
| app-info | Front app: name, bundle id, version, path → copy | Own addon |
| relaunch-app | Quit + reopen front app | Own addon |

### Files / clipboard

| Id | One-liner | Packaging |
|---|---|---|
| path-copy | Finder selection → path | **paths** |
| reveal-path | Clipboard path → Reveal in Finder | **paths** |
| count-files | Count items in front folder (± recursive) | **paths** |
| folder-size | Size of Finder selection / front folder | **paths** |
| uuid-gen | UUID / ULID / nanoid → clipboard | **clip-tools** |
| heic-jpeg | HEIC → JPEG via `sips` | **images** |
| resize-image | Resize clipboard image to width presets | **images** |
| image-rotate | Rotate 90° / flip clipboard or selection (+ other Image I/O ops) | **images** |
| md-link | Selection + URL → markdown link | **clip-tools** |
| scratch-folder | Dated `~/Scratch/…` + open | Standalone |
| clip-clear | Wipe general pasteboard | **clip-tools** |
| slugify | Clipboard → URL/file slug | **clip-tools** |
| json-pretty | Pretty/minify clipboard JSON | **clip-tools** |
| csv-pretty | Pretty/minify clipboard CSV | **clip-tools** |
| yaml-pretty | Pretty/minify clipboard YAML | **clip-tools** |
| xml-pretty | Pretty/minify clipboard XML | **clip-tools** |
| jwt-decode | Clipboard JWT → header/payload (no verify) | **clip-tools** |
| url-encode | URL-encode / decode clipboard | **clip-tools** |
| base64 | Encode/decode clipboard | **clip-tools** |
| timestamp | Now as unix / ISO / RFC3339 / local | **clip-tools** |
| text-stats | Words/chars/lines/reading time | **clip-tools** |
| case | lower / UPPER / Title / camel / snake / kebab | **clip-tools** |
| sort-lines | Sort clipboard lines | **clip-tools** |
| dedupe-lines | Dedupe clipboard lines | **clip-tools** |
| lorem | N words/paragraphs of placeholder text | **clip-tools** |
| regex-replace | Apply saved replace recipes to clipboard | **clip-tools** |
| hash | SHA-256 of clipboard text or selected file | **clip-tools** (file path via **paths** helpers if needed) |
| paste-as-plain | Paste/strip to plain text | **clip-tools** / **paste-transform**; also gap #8 / v0 path |
| tabs-spaces | Tabs ↔ spaces (width prompt) on clipboard text | **clip-tools** |
| invisible-chars | Show/strip ZWSP, NBSP, bidi marks on clipboard | **clip-tools** |
| markdown-table | TSV/CSV clipboard ↔ Markdown table | **clip-tools** |
| reverse-lines | Reverse clipboard line order | **clip-tools** |
| extract-emails | Pull emails from clipboard → list/copy | **clip-tools** |
| json-path | JSONPath / key path on clipboard JSON → copy result | **clip-tools** |
| csv-json | Clipboard CSV ↔ JSON (and yaml↔json, xml↔json, other same-shape converters) | **clip-tools** |
| unicode-name | Codepoint / Unicode name for clipboard character(s) | **clip-tools** |
| iso-week | Current ISO week number (+ copy) | **clip-tools** (timestamp / date family) |
| diff-clip | Diff two clipboard buffers / split | Own **diff** addon (or tiny mode on clip-tools) |
| clipboard-guard | Detect likely secrets, warn before history storage, clear, or redact clipboard | Own addon; heuristic detection |
| new-file | New empty/template file in front Finder folder | Own addon |
| zip-selection | Zip selected Finder items beside them | Own addon; shared helpers w/ **unarchive** |
| unarchive | Unzip selected archive beside it | Own addon; pair with zip-selection |
| archive-utility | Create archives, use compression presets, test integrity, or reveal the archive | Own addon; may absorb zip-selection and unarchive |
| reveal-downloads | Open / reveal ~/Downloads | **downloads-triage** |
| downloads-age | Triage Downloads older than N days (+ type/age variants) | **downloads-triage** |
| save-clipboard | Save clipboard text/image to Scratch or Downloads | Own addon |
| quick-capture | Capture clipboard, append to today, open latest, or reveal captures | Own addon; text first, images later |
| ocr | Clipboard image → text via Vision | Own addon |
| trash-selection | Move Finder selection to Trash | **trash-ui** command |
| empty-trash | Empty Trash (confirm) | **trash-ui** command |
| trash-put-back | Put back last trashed item(s) | **trash-ui** |
| screenshot-folder | Open the screenshots save folder | Own until **screenshot-inbox** (gap) |
| screenshot-inbox | Open inbox, reveal latest, archive latest, or archive older screenshots | Own addon; palette commands first, no background watcher in v0 |
| pdf-tools | Unlock, merge, split, extract, reorder, rotate, and the other shipped PDF commands. Later, one **Convert** panel (JPG → PDF, PDF → JPG, PDF → PNG) opened from the palette or Finder **Convert**. Word ↔ PDF and protect stay parked | Own **pdf-tools** addon (PDFKit) |
| large-files | Biggest files under home or chosen folder (depth-capped) | Own addon; complements disk-pressure gap |
| desktop-sweep | Move Desktop clutter into `Desktop/Archive-YYYY-MM-DD` | Own addon; ≠ downloads-triage |
| favorite-folders | Jump a curated folder list (not full-disk search) | Own addon |
| recent-files | Show recently modified files, filter by folder or extension, reveal/open, or copy path | Own addon; focused utility, not full-disk search |
| mount-dmg | Mount / unmount selected DMG or volume | Own addon |
| afconvert | Convert audio selection via macOS `afconvert` (+ preset siblings) | **media-convert** |
| qr-decode | Clipboard / selected image → decode QR payload | **qr-clip** |

### Window / focus

| Id | One-liner | Packaging |
|---|---|---|
| hide-others | Hide all other apps | **window-layouts** |
| fill-desktop | Front window → visible desktop | **window-layouts** |
| maximize | Grow to screen without fullscreen Space | **window-layouts**; clarify vs fill-desktop in UX |
| center-window | Center frontmost on current display | **window-layouts** |
| pin-top | Toggle always-on-top | **window-layouts** |
| space-jump | Jump to Space N | **window-layouts** |
| stage-toggle | Toggle Stage Manager | **window-layouts** |
| left-half | Snap front window to left half | **window-layouts** |
| right-half | Snap front window to right half | **window-layouts** |
| quarters | Snap to screen quarter | **window-layouts** |
| gather-windows | Gather front app’s windows to current Space/display | **window-layouts** |
| move-display | Move front window to next/previous display | **window-layouts** |
| app-windows | List front app’s windows → focus one | **window-layouts** |
| desktop-name | Jugnu-local label for the current Space (our lists only) | **window-layouts** |
| fullscreen-toggle | Toggle native fullscreen on front window | **window-layouts** |
| minimize-all | Minimize all windows (optional: except front) | **window-layouts** |
| show-desktop | Show Desktop (hide all) / restore | **window-layouts** |
| zone-save / zone-apply | Snapshot / apply named geometry (max 6; seventh save is a replace picker) | **window-layouts** — not occupancy; **no undo** |
| tile-two | Side-by-side front + next app (+ swap / other layout ops) | **window-layouts** |

### System QoL / appearance

| Id | One-liner | Packaging |
|---|---|---|
| dark-mode | Toggle / set Light or Dark | Addon dark-mode |
| night-shift | Toggle Night Shift | Own addon |
| true-tone | Toggle True Tone | Own addon |
| display-brightness | Brightness presets | Own addon |
| desktop-icons | Show/hide desktop icons | **desktop-toggles**; helper for screenshare-prep |
| dock-autohide | Toggle Dock autohide | **desktop-toggles** |
| menubar-autohide | Toggle menu bar autohide | **desktop-toggles** |
| screensaver | Start screensaver now | **desktop-toggles** or lock-adjacent |
| wallpaper-shuffle | Random wallpaper from folder | Own or **desktop-toggles** |
| hot-corners | Show or open Hot Corners settings | Own addon |
| wifi-toggle | Wi‑Fi off/on / reconnect | **network** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| lock-screen | Lock screen | Standalone |
| low-power | Toggle Low Power Mode | Standalone |
| reminder-add | Quick-add Reminder | Standalone |
| next-event | Next calendar event; Open / Join | Standalone; lite vs meeting-bar |
| unit-convert | Broad unit conversion → clipboard | Standalone |
| kitchen-timer | One-shot countdown + chime | Standalone; ≠ pomodoro; ≠ focus-until; ≠ stopwatch |
| notify-clear | Clear Notification Center | Own; private API risk |
| login-items | List / open Login Items | Own or Settings deep-link |
| password-gen | Generate password → clipboard | Own security addon — not a Play-category toy |
| password-options | Passphrase / PIN / exclude-ambiguous / copy-once / strength variants | **password-gen** |
| hidden-files | Toggle Finder show-hidden files | **finder-toggles** |
| path-bar | Toggle Finder path bar | **finder-toggles** |
| status-bar | Toggle Finder status bar | **finder-toggles** |
| restart-finder | Relaunch Finder | **finder-toggles** |
| resolution-preset | Jump to named resolution / HiDPI preset | Own addon |
| display-sleep | Sleep displays now | **sleep** |
| sleep-now | Sleep Mac now (confirm) | **sleep** |
| default-browser | Pick default browser from installed list | **default-apps** command. List locked in [catalog-commands](catalog-commands.md). Not scaffolded. |
| settings-jump | Palette → jump to a System Settings pane | Own addon |
| memory-pressure | Memory pressure + top memory apps | Own addon; pair conceptually w/ disk-pressure gap |
| speak-clip | Speak clipboard text (or stop speaking) | Own addon |
| nudges | Wellness reminder rows: eye-rest / water / stretch | **intervals** |
| eye-rest | 20-20-20 look-away nudge | **intervals** |
| water-nudge | Hydrate reminder | **intervals** |
| stretch-nudge | Stand/stretch reminder | **intervals** |
| time-machine | Status / start backup / open Time Machine | Own addon |
| note-pin | Pin floating note above other windows | **floating-note** |
| quick-note | Throwaway floating note: close / Cmd+W discards; nothing survives quit or reopen | **floating-note** — not its own zip; shell `note` pattern `persist: false`. Scratchpad stays `open` (`persist: true`) |
| world-overlap | Overlap helper for “when is 9–10 across cities?” | **world-clock** |
| pomodoro-skip | Skip / extend / log interruption (+ other session controls) | **intervals** |

### Fun — Play category (one addon per id)

Lifecycle split (epic [0057](architecture/2026-08-30-addon-process-lifecycle-design.md)): `dice-roll`, `coin-flip`, `pick-one`, `number-guess`, `eight-ball`, `rps`, `fortune`, `tic-tac-toe` are `oneshot` (re-invoke per move for tic-tac-toe on `canvas`) — buildable on the shipped lifecycle model. `chess-clock`, `breathing`, `reaction-time`, `stopwatch`, `memory`, `hangman` are **`session`-shaped** (a live process the panel drives / that ticks on its own) — **blocked on epic [0059](tickets.md)** (`session` class + addon IPC).

| Id | One-liner | Packaging |
|---|---|---|
| dice-roll | `2d6+1` → toast + clipboard | Own addon; Play category |
| coin-flip | Heads/tails (± best-of-N) | Own addon; Play category |
| pick-one | Random pick from options/lines | Own addon; Play category |
| number-guess | 1–100 guess loop | Own addon; Play category |
| hangman | Offline hangman in palette | Own addon; Play category |
| eight-ball | Magic 8-Ball answer | Own addon; Play category |
| chess-clock | Simple dual chess clock | Own addon; Play category |
| rps | Rock–paper–scissors | Own addon; Play category |
| stopwatch | Start / lap / stop | Own addon; Play category; ≠ kitchen-timer |
| memory | Tiny card-match in palette | Own addon; Play category; ambitious UX |
| breathing | Box / 4-7-8 breathing guide | Own addon; Play category |
| reaction-time | Click-when-green mini test | Own addon; Play category |
| tic-tac-toe | Quick local tic-tac-toe | Own addon; Play category |
| fortune | Random short fortune/epigram → notification or clipboard | Own addon; Play category; quotes ship in this zip |

### Design

| Id | One-liner | Packaging |
|---|---|---|
| sf-symbols | Search SF Symbol → copy name | Own addon (also listed under Dev historically) |
| type-scale | Modular type scale from base size | **design-calc** |
| rem-px | rem ↔ px at root font size | **design-calc** |
| aspect-ratio | Missing side / ratio from W×H (+ spacing-scale and other design math) | **design-calc** |
| color-format | Hex ↔ rgb/hsl ↔ SwiftUI `Color` / UIColor snippets | **color-eyedropper** |
| grid-overlay | Toggle simple column/baseline overlay on screen | Own addon |
| emoji-picker | Search emoji → copy (Character Viewer lite) | Own addon; keep tiny |

## Related Tools CLIs (stay in Tools)

Integrate as addons/dependencies; do not rewrite unless needed:

`port-tool`, `trash`, `pb`, `notify`, `qr-encode`, `color-convert`, `file-snippets`, and other nursery CLIs.

Claude usage / session tools: include only if explicitly moved; not currently in this repo.

## Out of scope rabbit holes

- Day-one Alfred-class general file search (unless designing shell search)
- Merging Tools into Jugnu
- Accessibility-heavy snippet expand before paste paths
