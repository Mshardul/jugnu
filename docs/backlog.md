# Jugnu backlog

Status legend for staged leaves: **active** = runnable code; **stub** = README only; **icebox** / **later** = defer.

## Platform (build order)

| Priority | Item | Notes |
|---|---|---|
| 1 | Shell + YAML addon enablement | Design before scaffold — see `docs/architecture/` |
| 2 | Dual clipboard modes | Ephemeral vs history; privacy-aware; build on `apps/clipboard-history` |
| 3 | Robust window management | Absorb `window-layouts` / `layout-save` stubs into a real first-party addon — [spec](architecture/2026-08-24-window-layouts.md) · [ticket 0046](tickets.md) |
| 4 | Addon **popup UI** host | [UI + speed design](architecture/2026-08-22-addon-ui-speed-design.md) (Approved) · [P1 plan](superpowers/plans/2026-08-22-addon-ui-host-p1.md) **done** |
| 5 | **Speed** budget | Invoke → visible result; budgets in that design §6 |
| 6 | Context-aware UI (later) | Reserved in UI + speed §7 — after UI host exists |
| 7 | Palette + addon UI **product pass** | [2026-08-23 spec](architecture/2026-08-23-palette-ui-product-pass.md) · [plan](superpowers/plans/2026-08-23-palette-ui-product-pass.md) — search quality, AppKit→SwiftUI panel rewrite onto shared design tokens, user-editable light/dark theming, keyboard/motion accessibility, first-run recommended-set refresh, live-verification suite. **Implemented; walk [shell-smoke.md](architecture/shell-smoke.md)** |
| 8 | Persistent latency logging (future epic) | [Ticket 0001](tickets.md) — JSON-lines, capped retention, timing/ids only, never payload |
| 9 | Addon management / settings (future epic) | [Ticket 0002](tickets.md) taxonomy/install. Chrome: [0008](tickets.md) **done** ([one panel, presets, stack](architecture/2026-08-23-shell-surface-presets.md)). Slices [0005](tickets.md), [0009](tickets.md), [0011](tickets.md) done; [0006](tickets.md), [0007](tickets.md), [0010](tickets.md), [0012](tickets.md) still open — walk [shell-smoke.md](architecture/shell-smoke.md) manual section before closing further |
| 10 | Security audit (future epic) | [Ticket 0003](tickets.md) — seeded with a real zip-slip finding in `AddonInstaller.unzip()`; expect more findings from a full pass on installer/runner/registry-trust |

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
8. Paste plain / strip formatting (or fold into paste-transform) — also accepted as **paste-as-plain** under clip-tools
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
| Appearance | **desktop-toggles** | desktop-icons, dock-autohide, menubar-autohide | Closely related desktop toggles |
| Appearance | **wallpaper-shuffle** | shuffle from folder | Optional; or under desktop-toggles |
| Appearance | **screensaver** | start now | Small; desktop-toggles or Security |
| Appearance | **hot-corners** | show / open Hot Corners | Thin Settings surface |
| Appearance | **finder-toggles** | **hidden-files**, **path-bar**, **status-bar**, **restart-finder** (+ tab bar / other Finder chrome) | Finder chrome — not desktop-toggles |
| Appearance | **resolution-preset** | named resolution / HiDPI presets | Own display job |
| Clipboard | **clip-tools** (or **paste-transform**) | slugify, json/csv/yaml/xml-pretty, base64, url-encode/decode, jwt-decode, timestamp, text-stats, uuid, md-link, clip-clear, **case**, **sort-lines**, **dedupe-lines**, **lorem**, **regex-replace**, **hash**, **paste-as-plain**, **tabs-spaces**, **invisible-chars**, **markdown-table**, **reverse-lines**, **extract-emails**, **json-path**, **csv-json** (+ yaml↔json, xml↔json, and other same-shape converters), **unicode-name**, **iso-week** | Converters/formatters as commands; paste-as-plain also gap #8 |
| Clipboard | **clipboard-guard** | detect likely secrets / warn before history storage / clear or redact clipboard | Privacy utility for clipboard workflows; detection is heuristic |
| Clipboard | **diff** | diff-clip | Heavier than one-shot transforms — own addon unless kept tiny on clip-tools |
| Files | **paths** | path-copy, reveal-path, **count-files**, **folder-size** | Path/Finder folder jobs |
| Files | **images** | heic-jpeg, resize-image, **image-rotate**, flip, format convert, compress (+ other `sips`/Image I/O ops) | Image transforms family |
| Files | **downloads-triage** (staged) | reveal-downloads, **downloads-age** (+ type/age triage variants) | Downloads job |
| Files | **new-file** | create in front Finder folder | Own file job |
| Files | **zip-selection** | zip Finder selection | Pair with unarchive; shared archive helpers in zips |
| Files | **unarchive** | unzip archive beside it | Pair with zip-selection |
| Files | **archive-utility** | create archives / compression presets / test integrity / reveal archive | Archive workflow; may eventually absorb zip-selection and unarchive |
| Files | **save-clipboard** | clipboard → Scratch/Downloads | May share path helpers w/ scratch-folder |
| Files | **quick-capture** | capture clipboard / append to today / open latest / reveal captures | Intentional clipboard-to-file capture; text first, images later |
| Files | **ocr** | image → text (Vision) | Own; permission-heavy |
| Files | **trash-ui** (staged) | trash-selection, empty-trash, **trash-put-back** | Trash jobs on trash-ui |
| Files | **screenshot-folder** | open screenshots location | Own until screenshot-inbox (gap) absorbs it |
| Files | **screenshot-inbox** | open inbox / reveal latest / archive latest / archive older | Screenshot organization job; palette commands first, no background watcher in v0 |
| Files | **pdf-tools** | merge / split / page-count PDFs (+ compress and same-shape PDF ops) | Same-shape PDF jobs — not on images |
| Files | **large-files** | biggest files under folder (depth-capped) | Own; complements disk-pressure gap |
| Files | **desktop-sweep** | archive Desktop clutter to dated folder | Own; ≠ downloads-triage |
| Files | **mount-dmg** | mount / unmount selected DMG or volume | Own volume job |
| Files | **media-convert** | **afconvert** (+ other built-in audio convert presets) | Audio via macOS `afconvert` |
| Files | **favorite-folders** | jump curated folder list | Own; curated ≠ Alfred disk search |
| Files | **recent-files** | recently modified files / filter by folder or extension / reveal or open / copy path | Focused recent-file utility; not full-disk search |
| Window | **window-layouts** | center, fill-desktop, maximize, hide-others, pin-top, space-jump, stage-toggle, left/right-half, quarters, gather-windows, move-display, app-windows, desktop-name (Jugnu-local label), fullscreen-toggle, minimize-all, show-desktop, **tile-two** (+ swap / other layout ops); **zones** (save/apply, max 6, replace picker). Fold **layout-save**. **No layout-undo.** Snap board + palette commands. Spec: [2026-08-24 window-layouts](architecture/2026-08-24-window-layouts.md) | One window family |
| Meeting | **screenshare-prep** | hide icons + pause banners; **screenshare-restore** | Orchestrator + one-shot undo |
| Meeting | **mute-all** (`addons/mute-all`) | mute mic+speakers / restore; **mute-status** later (menu glyph) | Mute everything + visible state |
| Meeting | **display-mirror** | mirror vs extend | Own display job |
| Meeting | **focus-until** (or on **focus-toggle**) | Focus for duration / until time | Timed Focus |
| Meeting | **volume-presets** | named output levels | May share audio helpers w/ speaker-mute / audio-output |
| Meeting | **record-screen** | start/stop screen recording | Own; permission-heavy |
| Meeting | **flash-attention** | bounce Dock / flash screen | Physical “hey” — own tiny addon |
| Meeting | **meeting-join** | clipboard URL → join; **meeting-app-pick** | Join + app chooser form |
| Network | **hosts** | named blocks on/off; **hosts-backup** / restore | Own power-user job + safety |
| Network | **ping** | ping host from clipboard/typed | Own or net-info w/ copy-ip |
| Network | **ports** | list listeners, kill by pid/port (folds port-scan-local, port-picker, gap common-ports) | `addons/ports` — one surface |
| Network | **http-status** | HEAD/GET status + timing; **http-headers** (+ copy as markdown / other probe views) | Own; may later share **net-probe** w/ ping |
| Dev | **git-root** | reveal git root of front path | Own or near repo-jumper |
| Dev | **open-url** | open clipboard URL in chosen browser; **open-url-profile** | Browser + profile chooser |
| Dev | **brew-outdated** (staged) | brew-services, **brew-cleanup**, doctor/update and other brew ops | One Homebrew job shelf |
| Dev | **process-find** | process-list, find-by-name, **process-sort** (CPU/mem) (+ force-quit / copy PID variants) | ≠ quit-heavy, ≠ kill-hung |
| Dev | **open-terminal-here** (`addons/open-terminal-here`) | last-picked terminal at Finder folder; **term-app-pick** later | Dev QoL |
| Dev | **app-info** | front app name / bundle id / version / path | Own support blurb |
| Dev | **relaunch-app** | quit + reopen front app | Own |
| System | **notify-clear** | clear Notification Center | Own; private API risk |
| System | **login-items** | list / open Login Items | Own or Settings deep-link |
| System | **sleep** | sleep-now, display-sleep | Power sleep family |
| System | **keep-awake** (`addons/keep-awake`) | 15m / 1h / 2h / until-off; stop; status | Idle sleep + display; lid can still sleep |
| System | **settings-jump** | palette → System Settings pane | Own |
| System | **default-browser** | pick default browser | Own; pairs with open-url |
| System | **memory-pressure** | pressure + top memory apps | Own; pair conceptually w/ disk-pressure gap |
| System | **speak-clip** | speak clipboard / stop | Own a11y job |
| System | **nudges** | **eye-rest**, **water-nudge**, **stretch-nudge** (same timer shell; different copy/art/GIF per kind) | One wellness nudge addon |
| System | **time-machine** | status / start backup / open Time Machine | Own |
| System | **floating-note** (staged) | `open` (scratchpad, persist on close/quit), **quick-note** (throwaway; close discards), **note-pin** | One note addon: persistent scratchpad vs session scrap; pin is chrome QoL |
| System | **world-clock** (staged) | + **world-overlap** | Clocks + meeting overlap |
| System | **pomodoro** (staged) | **pomodoro-skip**, extend, log interruption (+ other session controls) | Focus timer forms |
| Security | **password-gen** | random password; **password-options** (passphrase / PIN / exclude-ambiguous / copy-once / …) | Own — not under play |
| Play | *(each id its own zip)* | dice-roll, coin-flip, pick-one, number-guess, hangman, eight-ball, chess-clock, rps, stopwatch, memory, breathing, reaction-time, tic-tac-toe, fortune | Play is a **category**, not one shelf. Shared RNG/timer code is a **helper** ([0047](tickets.md)) — ship that before any Play zip. **Bundles** later ([0048](tickets.md)); 14 separate catalog rows is fine until then. |
| Design | **sf-symbols** | pick/copy | Solo for now |
| Design | **design-calc** | type-scale, rem-px, **aspect-ratio** (+ spacing-scale and other design math) | Design math shelf |
| Design | **color-eyedropper** (staged) | + color-format | Eyedropper + hex/SwiftUI format commands |
| Design | **grid-overlay** | column/baseline overlay | Own design-QA overlay |
| Design | **emoji-picker** | search emoji → copy | Own; keep tiny |
| Design | **qr-clip** (staged) | encode + **qr-decode** | QR both directions |
| Tools | **unit-convert** | all units | One converter addon |
| *(own addons)* | — | mic-picker, camera-check, speaker-mute, copy-ip, dns-flush, proxy-toggle, quit-heavy, vpn-connect, scratch-folder, wifi-toggle, lock-screen, low-power, reminder-add, next-event, kitchen-timer, flash-attention, http-status, process-find, large-files, pdf-tools, desktop-sweep, speak-clip, resolution-preset, finder-toggles, default-browser, settings-jump, sleep, memory-pressure, nudges, grid-overlay, design-calc, app-info, relaunch-app, favorite-folders, time-machine, emoji-picker, media-convert, mount-dmg | Distinct jobs |

### Meeting / device

| Id | One-liner | Packaging |
|---|---|---|
| mic-picker | Switch default input device | Standalone (later w/ gap audio-output) |
| meeting-join | Clipboard meeting URL → join | Own; **meeting-app-pick** chooses Zoom/Meet/Teams/browser |
| meeting-app-pick | Choose which app opens a meeting URL | **meeting-join** form |
| camera-check | Short camera preview before video | Standalone |
| speaker-mute | Mute/unmute output only | Standalone (or audio-device family) |
| screenshare-prep | Hide desktop icons + pause banners for N min | May call **desktop-toggles** |
| screenshare-restore | One-shot undo for screenshare-prep | **screenshare-prep** |
| mute-all | Mute mic + speakers; restore prior state | Own; shared audio helpers **or** invoke mic-mute + speaker-mute |
| mute-status | Menu-bar glyph while mute-all / mic-mute active | **mute-all** / **mic-mute** (shared indicator helper OK) |
| display-mirror | Mirror vs extend for a chosen display | Own addon |
| focus-until | Focus/DND for N minutes / until a time | Own **or** on **focus-toggle** |
| volume-presets | Jump output volume to named levels | Own; may share helpers w/ speaker-mute |
| record-screen | Start/stop macOS screen recording | Own; permission-heavy |
| flash-attention | Bounce Dock / flash screen so someone at desk notices you | Own tiny addon |

### Devops / network / dev

| Id | One-liner | Packaging |
|---|---|---|
| copy-ip | Copy LAN (optional public) IP | Standalone / net-info |
| dns-flush | Flush DNS cache | Standalone / net-info |
| proxy-toggle | System proxy on/off | Standalone / net-info |
| quit-heavy | Top CPU/mem → quit | Standalone; ≠ kill-hung |
| vpn-connect | Named VPN connect/disconnect | Standalone / net-info |
| hosts | Enable/disable named `/etc/hosts` blocks | Own addon |
| hosts-backup | Snapshot `/etc/hosts` before toggle; restore prior snapshot | **hosts** |
| ping | Ping host from clipboard or typed input | Own or net-info w/ copy-ip |
| port-scan-local | List listening ports on this Mac | Merged into **ports** (`addons/ports`) |
| git-root | Reveal git root of front Finder/Terminal path | Own or near **repo-jumper** |
| open-url | Open clipboard URL in a chosen browser | Own addon |
| open-url-profile | Open URL in a chosen browser *profile* (Chrome/Safari/…) | **open-url** |
| http-status | HEAD/GET clipboard URL → status + final URL + timing | Own; may later share **net-probe** w/ ping |
| http-headers | Copy response headers / timing (e.g. as markdown) | **http-status** |
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
| pdf-tools | Merge / split / page-count selected PDFs (+ compress and siblings) | Own **pdf-tools** addon (PDFKit) |
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
| wifi-toggle | Wi‑Fi off/on / reconnect | Standalone / net-info |
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
| default-browser | Pick default browser from installed list | Own addon; pairs with **open-url** |
| settings-jump | Palette → jump to a System Settings pane | Own addon |
| memory-pressure | Memory pressure + top memory apps | Own addon; pair conceptually w/ disk-pressure gap |
| speak-clip | Speak clipboard text (or stop speaking) | Own addon |
| nudges | Wellness nudge shell: eye-rest / water / stretch (same timer; different copy/GIF) | Own **nudges** addon |
| eye-rest | 20-20-20 look-away nudge | **nudges**; ≠ pomodoro / kitchen-timer |
| water-nudge | Hydrate reminder | **nudges** |
| stretch-nudge | Stand/stretch reminder | **nudges** |
| time-machine | Status / start backup / open Time Machine | Own addon |
| note-pin | Pin floating note above other windows | **floating-note** |
| quick-note | Throwaway floating note: close / Cmd+W discards; nothing survives quit or reopen | **floating-note** — not its own zip; shell `note` pattern `persist: false`. Scratchpad stays `open` (`persist: true`) |
| world-overlap | Overlap helper for “when is 9–10 across cities?” | **world-clock** |
| pomodoro-skip | Skip / extend / log interruption (+ other session controls) | **pomodoro** |

### Fun — Play category (one addon per id)

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

## Staged leaves — `apps/`

7 of these leaves have graduated to native addons under `addons/` (rewritten as
`exec`/JXA entrypoints — no user Python; see `addons/README.md`). The Python
versions here stay as reference implementations, not shipped.

| Leaf | Status | Role for Jugnu |
|---|---|---|
| clipboard-history | graduated → `addons/clipboard-history` | Background launchd watcher + sqlite3 CLI store; list UI, copy-back |
| battery-eta | graduated → `addons/battery-eta` | `pmset` parse; toast |
| brew-outdated | graduated → `addons/brew-outdated` | JXA (`osascript -l JavaScript`) for real JSON parsing; list UI |
| floating-note | graduated → `addons/floating-note` | `note` UI pattern (always-on-top editable panel). Shipped command is persist-on-close scratchpad (`open`). Backlog: **quick-note** (ephemeral) + **note-pin** |
| pomodoro | graduated → `addons/pomodoro` | Fire-and-forget background timer + notification; state file |
| weather-bar | graduated → `addons/weather-bar` | `curl` + Open-Meteo; toast |
| world-clock | graduated → `addons/world-clock` | Fixed zone list in script; list UI |
| tools-palette | stub | Nursery CLI runner — evolves into shell search surface or thin addon |
| window-layouts | graduated → `addons/window-layouts` | Window family; zones (max 6), tile-two, snap board; **no** layout-undo. Spec [2026-08-24](architecture/2026-08-24-window-layouts.md) |
| layout-save | folded | Folded into window-layouts **zones** (not undo) |
| meeting-bar | stub | Meeting/device QoL |
| paste-transform | stub | Paste plain / transforms; clip-tools host for converters |
| port-picker | superseded | Folded into `addons/ports` (list + kill; no longer wraps Tools `port-tool`) |
| trash-ui | stub | May wrap Tools `trash`; + trash-put-back |
| color-eyedropper | stub | Utility addon; absorb color-format commands |
| qr-clip | stub | May wrap Tools `qr-encode`; + qr-decode |
| downloads-triage | stub | File triage; + downloads-age |
| repo-jumper | stub | Dev QoL |
| ssh-host-picker | stub | Dev QoL |
| app-launcher | stub / icebox | Ecosystem war; Jugnu *is* the launcher |

## Staged leaves — `extensions/macos/`

| Leaf | Status | Role for Jugnu |
|---|---|---|
| airdrop-folder | active | Finder / share QoL |
| focus-toggle | active | Meeting/device QoL |
| mic-mute | active | Meeting/device QoL; shares mute-status indicator w/ mute-all |
| open-terminal-here | graduated → `addons/open-terminal-here` | Dev QoL; last-picked app; **term-app-pick** later |
| quarantine-clear | active | File / Gatekeeper QoL |
| snippet-expand | stub / later | Prefer clipboard/hotkey paste first |

## Related Tools CLIs (stay in Tools)

Integrate as addons/dependencies; do not rewrite unless needed:

`port-tool`, `trash`, `pb`, `notify`, `qr-encode`, `color-convert`, `file-snippets`, and other nursery CLIs.

Claude usage / session tools: include only if explicitly moved; not currently in this repo.

## Out of scope rabbit holes

- Day-one Alfred-class general file search (unless designing shell search)
- Merging Tools into Jugnu
- Accessibility-heavy snippet expand before paste paths
