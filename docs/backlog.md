# Jugnu backlog

Status legend for staged leaves: **active** = runnable code; **stub** = README only; **icebox** / **later** = defer.

## Platform (build order)

| Priority | Item | Notes |
|---|---|---|
| 1 | Shell + YAML addon enablement | Design before scaffold — see `docs/architecture/` |
| 2 | Dual clipboard modes | Ephemeral vs history; privacy-aware; build on `apps/clipboard-history` |
| 3 | Robust window management | Absorb `window-layouts` / `layout-save` stubs into a real first-party addon |

## Gap list (keep / build)

Not yet staged as leaves. Candidates after shell MVP:

1. Audio output switcher
2. Caffeine / keep-awake
3. Webcam mute
4. AirPods / BT battery bar
5. Claude/agent mission control (lite)
6. Dev-server / common-ports bar
7. Screenshot inbox
8. Paste plain / strip formatting (or fold into paste-transform)
9. Kill hung app picker
10. Disk pressure bar

## Accepted addons (not staged yet)

Accepted for backlog — still **not** scaffolded. Build later.

**Canonical rules:** [`docs/vision.md`](vision.md) — *Catalog hierarchy* (Category → Addon → Commands) and **shared-capability rule** (own addon vs files bundled into each zip).  
Ids below are **capability ids**; several become **commands** on one **addon** zip. Do not treat every row as its own zip.

### Packaging map (preferred addon → commands)

Draft boundaries — refine by user mental model (not “all toggles in one zip”).  
**Ids name the job** a user would search for — not the scenario you imagined when inventing them (e.g. mute mic+speakers is `mute-all`, not `call-mute-all`).

| Category (browse) | Addon (zip) | Commands / capability ids | Why |
|---|---|---|---|
| Appearance | **dark-mode** | toggle / set light / set dark | One addon for appearance mode — not separate light vs dark apps |
| Appearance | **night-shift** | toggle | Own job; don’t merge with dark-mode unless UX says so |
| Appearance | **display-brightness** | presets | Brightness job |
| Appearance | **desktop-toggles** | desktop-icons, dock-autohide, menubar-autohide | Closely related desktop toggles (avoid “chrome” — sounds like the browser) |
| Appearance | **wallpaper-shuffle** | shuffle from folder | Optional; or command under desktop-toggles later |
| Appearance | **screensaver** | start now | Small; could sit under desktop-toggles or Security |
| Clipboard | **clip-tools** (or **paste-transform**) | slugify, json/csv/yaml/xml-pretty, json↔csv (later), base64, url-encode/decode, jwt-decode, timestamp, text-stats, uuid, md-link, clip-clear | Same I/O shape — converters/formatters as commands on one addon |
| Files | **paths** | path-copy, reveal-path | Inverse pair |
| Files | **images** | heic-jpeg, resize-image | Image transforms |
| Files | **downloads-triage** (staged) | + **reveal-downloads** | Jump to Downloads belongs with downloads job |
| Files | **new-file** | create empty / from template in front Finder folder | Own file job |
| Files | **zip-selection** | zip Finder selection beside items | Own file job |
| Files | **save-clipboard** | save clipboard text/image to Scratch/Downloads | Own job; may share path helpers with scratch-folder via bundled files |
| Files | **ocr** | clipboard image → text (Vision) | Own job; permission-heavy |
| Window | **window-layouts** (staged; drop “window-quick”) | center, fill-desktop, hide-others, pin-top, space-jump, stage-toggle, left-half, right-half, quarters, gather-windows | One Accessibility/window family |
| Meeting | **screenshare-prep** | hide icons + pause banners for N min (+ may invoke desktop-icons) | What the user is preparing for |
| Meeting | **mute-all** | mute mic+speakers / restore | Job is mute everything — not “call” |
| Meeting | **display-mirror** | mirror vs extend for chosen display | Own display job |
| Meeting | **focus-until** (or commands on **focus-toggle**) | Focus/DND for duration / until time | Timed Focus; prefer graduating onto focus-toggle if that leaf absorbs it |
| Play | **play** | dice-roll, coin-flip, pick-one, number-guess, hangman, eight-ball, chess-clock (+ later) | Fun shelf; more commands later |
| Design | **sf-symbols** | pick/copy | Solo for now; later with color-eyedropper |
| Tools | **unit-convert** | parse/convert (all units) | One converter addon — not per-unit zips |
| *(own addons)* | — | mic-picker, meeting-join, camera-check, speaker-mute, copy-ip, dns-flush, proxy-toggle, quit-heavy, vpn-connect, scratch-folder, wifi-toggle, lock-screen, low-power, reminder-add, next-event, kitchen-timer | Distinct user jobs / permissions |

### Meeting / device

| Id | One-liner | Packaging |
|---|---|---|
| mic-picker | Switch default input device | Standalone (audio device family later w/ gap audio-output) |
| meeting-join | Clipboard meeting URL → join | Standalone |
| camera-check | Short camera preview before video | Standalone |
| speaker-mute | Mute/unmute output only | Standalone (or audio-device family) |
| screenshare-prep | Hide desktop icons + pause banners for N min | Addon orchestrator; may call **desktop-toggles** commands |
| mute-all | Mute mic + speakers; restore prior state | Own addon; shared audio helpers in zip **or** invoke mic-mute + speaker-mute |
| display-mirror | Mirror vs extend for a chosen display | Own addon |
| focus-until | Focus/DND for N minutes / until a time | Own addon **or** commands on **focus-toggle** when graduated |

### Devops

| Id | One-liner | Packaging |
|---|---|---|
| copy-ip | Copy LAN (optional public) IP | Standalone (or future net-info w/ dns-flush) |
| dns-flush | Flush DNS cache | Standalone / net-info |
| proxy-toggle | System proxy on/off | Standalone / net-info |
| quit-heavy | Top CPU/mem → quit | Standalone; ≠ kill-hung |
| vpn-connect | Named VPN connect/disconnect | Standalone / net-info |
| sf-symbols | Search SF Symbol → copy name | Standalone or with color-eyedropper later |

### Files / clipboard

| Id | One-liner | Packaging |
|---|---|---|
| path-copy | Finder selection → path | **paths** |
| reveal-path | Clipboard path → Reveal in Finder | **paths** |
| uuid-gen | UUID / ULID / nanoid → clipboard | **clip-tools** / paste-transform |
| heic-jpeg | HEIC → JPEG via `sips` | **images** |
| resize-image | Resize clipboard image to width presets | **images** |
| md-link | Selection + URL → markdown link | **clip-tools** |
| scratch-folder | Dated `~/Scratch/…` + open | Standalone |
| clip-clear | Wipe general pasteboard | **clip-tools** |
| slugify | Clipboard → URL/file slug | **clip-tools** |
| json-pretty | Pretty/minify clipboard JSON | **clip-tools** |
| csv-pretty | Pretty/minify clipboard CSV | **clip-tools** |
| yaml-pretty | Pretty/minify clipboard YAML | **clip-tools** |
| xml-pretty | Pretty/minify clipboard XML | **clip-tools** |
| jwt-decode | Clipboard JWT → header/payload (no verify) | **clip-tools** |
| url-encode | URL-encode / decode clipboard | **clip-tools** (encode + decode commands) |
| base64 | Encode/decode clipboard | **clip-tools** |
| timestamp | Now as unix / ISO / RFC3339 / local | **clip-tools** |
| text-stats | Words/chars/lines/reading time | **clip-tools** |
| new-file | New empty/template file in front Finder folder | Own addon |
| zip-selection | Zip selected Finder items beside them | Own addon |
| reveal-downloads | Open / reveal ~/Downloads | Command on **downloads-triage** (staged) |
| save-clipboard | Save clipboard text/image to Scratch or Downloads | Own addon; may bundle path helpers w/ scratch-folder |
| ocr | Clipboard image → text via Vision | Own addon |

### Window / focus

| Id | One-liner | Packaging |
|---|---|---|
| hide-others | Hide all other apps | **window-layouts** |
| fill-desktop | Front window → visible desktop | **window-layouts** |
| center-window | Center frontmost on current display | **window-layouts** |
| pin-top | Toggle always-on-top | **window-layouts** |
| space-jump | Jump to Space N | **window-layouts** |
| stage-toggle | Toggle Stage Manager | **window-layouts** (or desktop-toggles if treated as OS chrome) |
| left-half | Snap front window to left half | **window-layouts** |
| right-half | Snap front window to right half | **window-layouts** |
| quarters | Snap to screen quarter | **window-layouts** |
| gather-windows | Gather front app’s windows to current Space/display | **window-layouts** |

### System QoL / appearance

| Id | One-liner | Packaging |
|---|---|---|
| dark-mode | Toggle / set Light or Dark | **Addon** dark-mode (commands: toggle, set light, set dark) |
| night-shift | Toggle Night Shift | **Addon** night-shift |
| display-brightness | Brightness presets | **Addon** display-brightness |
| desktop-icons | Show/hide desktop icons | **desktop-toggles** command; helper for screenshare-prep |
| dock-autohide | Toggle Dock autohide | **desktop-toggles** command |
| menubar-autohide | Toggle menu bar autohide | **desktop-toggles** command |
| screensaver | Start screensaver now | **desktop-toggles** command or lock-adjacent |
| wallpaper-shuffle | Random wallpaper from folder | Own addon or **desktop-toggles** command |
| wifi-toggle | Wi‑Fi off/on / reconnect | Standalone / net-info |
| lock-screen | Lock screen | Standalone |
| low-power | Toggle Low Power Mode | Standalone |
| reminder-add | Quick-add Reminder | Standalone (or with next-event) |
| next-event | Next calendar event; Open / Join | Standalone; lite vs meeting-bar |
| unit-convert | Broad unit conversion → clipboard | Standalone |
| kitchen-timer | One-shot countdown + chime | Standalone; ≠ pomodoro; ≠ focus-until |

### Fun — **play** (one addon, many commands)

| Id | One-liner | Packaging |
|---|---|---|
| dice-roll | `2d6+1` → toast + clipboard | **play** |
| coin-flip | Heads/tails (± best-of-N) | **play** |
| pick-one | Random pick from options/lines | **play** |
| number-guess | 1–100 guess loop | **play** |
| hangman | Offline hangman in palette | **play** |
| eight-ball | Magic 8-Ball answer | **play** |
| chess-clock | Simple dual chess clock | **play** |

## Staged leaves — `apps/`

| Leaf | Status | Role for Jugnu |
|---|---|---|
| clipboard-history | active | Core input for clipboard addon |
| battery-eta | active | Menu-bar / status candidate |
| brew-outdated | active | Dev-ops menu bar |
| floating-note | active | First-party QoL |
| pomodoro | active | First-party QoL |
| weather-bar | active | Menu-bar candidate |
| world-clock | active | Menu-bar / palette |
| tools-palette | stub | Nursery CLI runner — evolves into shell search surface or thin addon |
| window-layouts | stub | Fold into window-management addon |
| layout-save | stub | Fold into window-management addon |
| meeting-bar | stub | Meeting/device QoL |
| paste-transform | stub | Paste plain / transforms |
| port-picker | stub | Dev-ops; may wrap Tools `port-tool` |
| trash-ui | stub | May wrap Tools `trash` |
| color-eyedropper | stub | Utility addon |
| qr-clip | stub | May wrap Tools `qr-encode` |
| downloads-triage | stub | File triage |
| repo-jumper | stub | Dev QoL |
| ssh-host-picker | stub | Dev QoL |
| app-launcher | stub / icebox | Ecosystem war; Jugnu *is* the launcher |

## Staged leaves — `extensions/macos/`

| Leaf | Status | Role for Jugnu |
|---|---|---|
| airdrop-folder | active | Finder / share QoL |
| focus-toggle | active | Meeting/device QoL |
| mic-mute | active | Meeting/device QoL |
| open-terminal-here | active | Dev QoL |
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
