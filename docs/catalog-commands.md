# Catalog — commands

Living inventory of **addon commands** (palette / menu searchable jobs). Grouped by browse **Category** → **Addon** (zip). Status is per capability id.

Companion: [catalog-ui.md](catalog-ui.md) (panels / mini-apps). Packaging rules: [vision.md](vision.md). Draft zip boundaries also live in [backlog.md](backlog.md); this file is the command-facing source of truth once a row lands here.

**Status**

| Marker | Meaning |
|---|---|
| `shipped` | In `addons/<id>/` and/or published registry zip |
| `planned` | Accepted; build when picked |
| `parked` | Keep on the list; needs tooling, permissions, or product lock before build |
| `demo` | Reference / non-product |

**Locks (2026-09-04)**

- **`paste-plain`** absorbed into `clip-tools` per [0074](tickets.md) (2026-09-12) — supersedes the 2026-09-04 "stays its own addon" lock below; both are stateless clipboard transforms.
- **`clip-tools`** = clipboard **text** transforms / formatters, now including pasteboard-format normalization (`paste-plain`).
- **`python-runtime` helper first**, then `clip-tools` (no in-zip CPython). Specs: [python-runtime](architecture/2026-09-04-python-runtime-helper-design.md) · [clip-tools](architecture/2026-09-04-clip-tools-design.md).
- **PDF** ops live on **`pdf-tools`**, not the text formatter UI.
- **Calculators** (EMI, GPA, GST, %, age, …) stay on the list under **Tools / calc**; not part of clip-tools.
- Heavy / unclear local path (background remover, upscaler, Word↔PDF, protect PDF) stay **`parked`**, not deleted.

---

## Appearance

### dark-mode — planned

| Command id | Title (search) | Status |
|---|---|---|
| `toggle` | Toggle Dark Mode | planned |
| `set-light` | Set Light Mode | planned |
| `set-dark` | Set Dark Mode | planned |

### night-shift — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Toggle Night Shift | planned |

### true-tone — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Toggle True Tone | planned |

### display-brightness — planned

| Command id | Title | Status |
|---|---|---|
| `presets` | Brightness presets | planned |

### finder-chrome — planned

One Finder/Desktop chrome addon. `finder-chrome` is the grid of live toggles. Absorbs desktop-toggles and finder-toggles ([0074](tickets.md)).

| Command id | Title | Status |
|---|---|---|
| `finder-chrome` | Finder and Desktop | planned |
| `desktop-icons` | Show or hide desktop icons | planned |
| `dock-autohide` | Dock autohide | planned |
| `menubar-autohide` | Menu bar autohide | planned |
| `hidden-files` | Finder hidden files | planned |
| `path-bar` | Finder path bar | planned |
| `status-bar` | Finder status bar | planned |
| `restart-finder` | Relaunch Finder | planned |

### wallpaper-shuffle — planned

| Command id | Title | Status |
|---|---|---|
| `shuffle` | Shuffle wallpaper from folder | planned |

### screensaver — planned

| Command id | Title | Status |
|---|---|---|
| `start` | Start screensaver | planned |

### hot-corners — planned

| Command id | Title | Status |
|---|---|---|
| `open` | Open Hot Corners settings | planned |

### resolution-preset — planned

| Command id | Title | Status |
|---|---|---|
| `apply` | Apply resolution / HiDPI preset | planned |

---

## Clipboard

### clipboard-history — shipped

| Command id | Title | Status |
|---|---|---|
| `list` | Clipboard history | shipped |
| `watch` | Clipboard watcher (daemon) | shipped |

### clip-tools — shipped (Phase 1)

Clipboard **text** format / convert / line tools. Palette one-shots + shared Transform panel later (see [catalog-ui](catalog-ui.md)). Requires helper `python-runtime`.

| Command id | Title | Status |
|---|---|---|
| `text-stats` | Word / char / line / reading time | shipped |
| `case` / `case-*` | Change text case | shipped |
| `sort-lines` | Sort lines | shipped |
| `reverse-lines` | Reverse lines | shipped |
| `dedupe-lines` | Remove duplicate lines | shipped |
| `trim-lines` | Trim line ends | shipped |
| `number-lines` | Number lines | shipped |
| `join-lines` | Join lines | shipped |
| `split-lines` | Split by delimiter | shipped |
| `prefix-suffix` | Add/remove prefix or suffix per line | shipped |
| `cut-field` | Cut Nth field (TSV/CSV lines) | shipped |
| `json-pretty` / `json-minify` | Pretty / minify JSON | shipped |
| `csv-pretty` | Pretty / minify CSV | shipped |
| `yaml-pretty` | Pretty / minify YAML | shipped |
| `xml-pretty` | Pretty / minify XML | shipped |
| `csv-json` / `json-csv` | CSV ↔ JSON | shipped |
| `yaml-json` / `json-yaml` | YAML ↔ JSON | shipped |
| `xml-json` | XML → JSON | shipped |
| `json-path` | JSONPath / key path | shipped |
| `base64-encode` / `base64-decode` | Base64 | shipped |
| `url-encode` / `url-decode` | URL encode / decode | shipped |
| `html-escape` / `html-unescape` | HTML escape / unescape | shipped |
| `jwt-decode` | Decode JWT (no verify) | shipped |
| `uuid` | UUID / ULID-like / nanoid | shipped |
| `timestamp` | Now as unix / ISO / RFC3339 / local | shipped |
| `iso-week` | ISO week number | shipped |
| `slugify` | Slugify clipboard | shipped |
| `hash` | Hash clipboard text or file | shipped |
| `tabs-spaces` | Tabs ↔ spaces | shipped |
| `invisible-chars` | Show / strip invisible chars | shipped |
| `markdown-table` | TSV/CSV ↔ Markdown table | shipped |
| `extract-emails` | Extract emails | shipped |
| `lorem` | Lorem placeholder | shipped |
| `regex-replace` | Regex replace recipes | shipped |
| `unicode-name` | Unicode name / codepoint | shipped |
| `md-link` | Selection + URL → markdown link | shipped |
| `clip-clear` | Clear clipboard | shipped |
| `paste-plain` | Paste as plain text (strip rich text) | shipped |
| `transform` | Open Transform panel | planned |

### clipboard-guard — planned

| Command id | Title | Status |
|---|---|---|
| `scan` | Detect likely secrets on clipboard | planned |
| `redact` | Redact / clear after warn | planned |

### diff — planned

Heavier two-buffer compare. Own addon unless kept tiny on clip-tools.

| Command id | Title | Status |
|---|---|---|
| `diff-clip` | Diff two clipboard buffers | planned |

---

## Files

### paths — planned

| Command id | Title | Status |
|---|---|---|
| `path-copy` | Copy path of Finder selection | planned |
| `reveal-path` | Reveal clipboard path in Finder | planned |
| `count-files` | Count items in folder | planned |
| `folder-size` | Folder / selection size | planned |

### images — planned

| Command id | Title | Status |
|---|---|---|
| `heic-jpeg` | HEIC → JPEG | planned |
| `format-convert` | JPG ↔ PNG ↔ WebP; EPS/DDS → PNG; image → PNG | planned |
| `resize` | Resize image | planned |
| `crop` | Crop image | planned |
| `compress` | Compress image | planned |
| `rotate` | Rotate image | planned |
| `flip` | Flip image | planned |
| `strip-exif` | Strip EXIF / metadata | planned |
| `favicon` | Favicon generator | planned |
| `background-remove` | Background remover | parked |
| `upscale` | Image upscaler | parked |

### folder-clutter — planned

One folder/file clutter addon. `folder-clutter` opens the list. Absorbs downloads-triage, screenshot-inbox, desktop-sweep, and large-files ([0074](tickets.md)).

| Command id | Title | Status |
|---|---|---|
| `folder-clutter` | Folder clutter | planned |
| `reveal-downloads` | Open Downloads | planned |
| `downloads-age` | Triage Downloads by age | planned |
| `screenshot-inbox` | Open the screenshot inbox | planned |
| `reveal-latest-screenshot` | Reveal the latest screenshot | planned |
| `archive-latest-screenshot` | Archive the latest screenshot | planned |
| `archive-older-screenshots` | Archive older screenshots | planned |
| `desktop-sweep` | Archive Desktop clutter | planned |
| `large-files` | Biggest files under a folder | planned |

### airdrop-folder — planned

| Command id | Title | Status |
|---|---|---|
| `share` | AirDrop Finder selection | planned |

### quarantine-clear — planned

| Command id | Title | Status |
|---|---|---|
| `clear` | Clear Gatekeeper quarantine | planned |

### new-file — planned

| Command id | Title | Status |
|---|---|---|
| `create` | New file in front Finder folder | planned |

### zip-selection — planned

| Command id | Title | Status |
|---|---|---|
| `zip` | Zip Finder selection | planned |

### unarchive — planned

| Command id | Title | Status |
|---|---|---|
| `unzip` | Unzip archive beside it | planned |

### archive-utility — planned

May absorb zip-selection / unarchive later.

| Command id | Title | Status |
|---|---|---|
| `create` | Create archive / presets | planned |
| `test` | Test archive integrity | planned |
| `reveal` | Reveal archive | planned |

### save-clipboard — planned

| Command id | Title | Status |
|---|---|---|
| `save` | Save clipboard to Scratch / Downloads | planned |

### quick-capture — planned

| Command id | Title | Status |
|---|---|---|
| `capture` | Capture clipboard to today | planned |
| `open-latest` | Open latest capture | planned |
| `reveal` | Reveal captures | planned |

### ocr — planned

| Command id | Title | Status |
|---|---|---|
| `image-text` | Image → text (Vision) | planned |
| `pdf-ocr` | PDF OCR | planned |

### trash-ui — planned

| Command id | Title | Status |
|---|---|---|
| `trash-selection` | Move selection to Trash | planned |
| `empty-trash` | Empty Trash | planned |
| `trash-put-back` | Put back last trashed | planned |

### screenshot-folder — planned

| Command id | Title | Status |
|---|---|---|
| `open` | Open screenshots folder | planned |

### pdf-tools

Separate from clip-tools / text Transform UI. One addon. The commands below are shipped. Word ↔ PDF and protect stay parked. A shared page-preview studio is still unbuilt; these commands use a form, a list, or a toast.

Later, JPG → PDF, PDF → JPG, and PDF → PNG share one **Convert** panel (`fields`). `convert` opens it. Finder’s **Convert** item (JPEG and PDF) opens that panel with the file and its type already chosen, and does not convert on click. `jpg-pdf`, `pdf-jpg`, and `pdf-png` stay the direct jobs and open the same panel with that conversion selected. See [catalog UI](catalog-ui.md).

| Command id | Title | Status |
|---|---|---|
| `pdf-unlock` | Remove PDF password | shipped |
| `merge` | Merge PDFs | shipped |
| `split` | Split PDF | shipped |
| `extract-pages` | Extract pages | shipped |
| `organize` | Reorder PDF pages | shipped |
| `rotate` | Rotate PDF pages | shipped |
| `page-count` | Page count | shipped |
| `page-numbers` | Add page numbers | shipped |
| `bookmarks` | Add / edit bookmarks | shipped |
| `info` | PDF info | shipped |
| `extract-text` | Extract PDF text | shipped |
| `compress` | Compress PDF | shipped |
| `jpg-pdf` | JPG to PDF | shipped |
| `pdf-jpg` | PDF to JPG | shipped |
| `pdf-png` | PDF to PNG | shipped |
| `flatten-forms` | Flatten PDF forms | shipped |
| `grayscale` | Grayscale PDF | shipped |
| `word-pdf` | Word ↔ PDF | parked |
| `protect` | Protect PDF | parked |

### mount-dmg — planned

| Command id | Title | Status |
|---|---|---|
| `mount` | Mount DMG / volume | planned |
| `unmount` | Unmount | planned |

### media-convert — planned

| Command id | Title | Status |
|---|---|---|
| `afconvert` | Audio convert presets | planned |

### jump-to-location — planned

One jump-to-location addon. `jump-to-location` opens the list. Absorbs favorite-folders and recent-files ([0074](tickets.md)).

| Command id | Title | Status |
|---|---|---|
| `jump-to-location` | Jump to a folder or recent file | planned |
| `favorite-folders` | Jump a curated folder list | planned |
| `recent-files` | Recently modified files | planned |

### temporary-folder — shipped

One stable folder at `~/Temporary`. The command creates it if it is missing and opens a tray under the menu bar. Dropped files and folders are copied in. Files already there are left in place.

| Command id | Title | Status |
|---|---|---|
| `temporary-folder` | Temporary folder | shipped |

---

## Window

### window-layouts — shipped

| Command id | Title | Status |
|---|---|---|
| `snap-board` | Snap board | shipped |
| `left-half` | Left half | shipped |
| `right-half` | Right half | shipped |
| `quarters` | Quarter | shipped |
| `center-window` | Center window | shipped |
| `fill-desktop` | Fill desktop | shipped |
| `maximize` | Maximize | shipped |
| `fullscreen-toggle` | Fullscreen | shipped |
| `tile-two` | Tile two | shipped |
| `gather-windows` | Gather windows | shipped |
| `hide-others` | Hide others | shipped |
| `minimize-all` | Minimize all | shipped |
| `show-desktop` | Show desktop | shipped |
| `move-display` | Move to display | shipped |
| `app-windows` | App windows | shipped |
| `zone-save` | Save zone | shipped |
| `zone-apply` | Apply zone | shipped |
| `zone-delete` | Delete zone | shipped |
| `pin-top` | Pin on top | shipped |
| `space-jump` | Jump Space | shipped |
| `stage-toggle` | Stage Manager | shipped |
| `desktop-name` | Desktop name | shipped |

---

## Meeting

### mute-all — shipped

| Command id | Title | Status |
|---|---|---|
| `toggle` | Mute all / restore | shipped |
| `mute-status` | Menu glyph while muted | planned |

### mic-mute — shipped

| Command id | Title | Status |
|---|---|---|
| `toggle` | Mute microphone | shipped |

### focus-toggle — shipped

| Command id | Title | Status |
|---|---|---|
| `toggle` | Toggle Focus | shipped |

### focus-until — planned

Own or on `focus-toggle`.

| Command id | Title | Status |
|---|---|---|
| `until` | Focus for duration / until time | planned |

### screenshare-prep — planned

| Command id | Title | Status |
|---|---|---|
| `prep` | Screenshare prep | planned |
| `restore` | Screenshare restore | planned |

### display-mirror — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Mirror / extend | planned |

### volume-presets — planned

| Command id | Title | Status |
|---|---|---|
| `apply` | Named output volume | planned |

### record-screen — planned

| Command id | Title | Status |
|---|---|---|
| `start-stop` | Start / stop screen recording | planned |

### flash-attention — planned

| Command id | Title | Status |
|---|---|---|
| `flash` | Bounce Dock / flash screen | planned |

### meeting-join — planned

| Command id | Title | Status |
|---|---|---|
| `join` | Join from clipboard URL | planned |
| `meeting-app-pick` | Choose meeting app | planned |

### meeting-bar — planned

| Command id | Title | Status |
|---|---|---|
| `next` | Next meeting / join lite | planned |

### mic-picker — planned

| Command id | Title | Status |
|---|---|---|
| `pick` | Switch default input | planned |

### camera-check — planned

| Command id | Title | Status |
|---|---|---|
| `preview` | Camera preview | planned |

### speaker-mute — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Mute speakers only | planned |

---

## Network

### ports — shipped

| Command id | Title | Status |
|---|---|---|
| `list` | Listening ports | shipped |

### network — planned

One network addon. `network` opens the list. Absorbs hosts, ping, http-status, copy-ip, dns-flush, proxy-toggle, vpn-connect, and wifi-toggle ([0074](tickets.md)). Ports stays its own addon.

| Command id | Title | Status |
|---|---|---|
| `network` | Network | planned |
| `copy-ip` | Copy LAN IP | planned |
| `dns-flush` | Flush DNS cache | planned |
| `proxy-toggle` | System proxy on or off | planned |
| `vpn-connect` | Connect or disconnect a VPN | planned |
| `wifi-toggle` | Wi-Fi off, on, or reconnect | planned |
| `ping` | Ping a host | planned |
| `hosts-block` | Enable or disable a hosts block | planned |
| `hosts-backup` | Snapshot or restore hosts | planned |
| `http-status` | HTTP status and timing | planned |
| `http-headers` | Copy response headers | planned |

---

## Dev

### brew-outdated — shipped

| Command id | Title | Status |
|---|---|---|
| `list` | Outdated Homebrew packages | shipped |
| `brew-services` | List / start / stop services | planned |
| `brew-cleanup` | brew cleanup | planned |
| `doctor` | brew doctor / update siblings | planned |

### open-terminal-here — shipped

| Command id | Title | Status |
|---|---|---|
| `open` | Open terminal at Finder folder | shipped |
| `term-app-pick` | Choose terminal app | planned |

### git-root — planned

| Command id | Title | Status |
|---|---|---|
| `reveal` | Reveal git root | planned |

### default-apps — planned

One default-app addon (Default Selection). `default-apps` opens the picker. Absorbs default-browser and open-url ([0074](tickets.md)).

| Command id | Title | Status |
|---|---|---|
| `default-apps` | Default apps | planned |
| `default-browser` | Pick the default browser | planned |
| `open-url` | Open a URL in a chosen browser | planned |
| `open-url-profile` | Open a URL in a chosen browser profile | planned |

### repo-jumper — planned

| Command id | Title | Status |
|---|---|---|
| `jump` | Jump known git repos | planned |

### ssh-host-picker — planned

| Command id | Title | Status |
|---|---|---|
| `connect` | Pick SSH host → connect | planned |

### process-find — planned

| Command id | Title | Status |
|---|---|---|
| `list` | Process list | planned |
| `find` | Find by name | planned |
| `sort` | Sort by CPU / mem | planned |

### app-control — planned

One app-control addon. `app-control` opens the front-app panel. Absorbs app-info and relaunch-app ([0074](tickets.md)).

| Command id | Title | Status |
|---|---|---|
| `app-control` | Front app | planned |
| `app-info` | Copy front app name, bundle id, version, and path | planned |
| `relaunch-app` | Quit and reopen the front app | planned |

### quit-heavy — planned

| Command id | Title | Status |
|---|---|---|
| `quit` | Quit top CPU / mem apps | planned |

---

## System

### keep-awake — shipped

| Command id | Title | Status |
|---|---|---|
| `pick` | Keep awake duration | shipped |
| `stop` | Stop keep-awake | shipped |
| `status` | Keep-awake status | shipped |
| `watch` | Daemon | shipped |

### intervals — shipped

One timer list. Recurring reminder rows plus a pomodoro preset (`kind: phases`) that alternates focus and break. Replaces `nudges` and `pomodoro` ([0074](tickets.md)).

| Command id | Title | Status |
|---|---|---|
| `manage` | Intervals | shipped |
| `nudge-now` | Show interval now | shipped |
| `pause` | Pause intervals | shipped |
| `resume` | Resume intervals | shipped |
| `restore-presets` | Restore interval presets | shipped |
| `advanced` | Interval template | shipped |
| `show-card` | Show interval card | shipped |
| `start-focus` | Start focus session | shipped |
| `start-break` | Start break | shipped |
| `pomodoro-status` | Pomodoro status | shipped |
| `reset-pomodoro` | Reset pomodoro | shipped |
| `phase-chime` | Phase chime | shipped |
| `pomodoro-skip` | Skip / extend / log interruption | planned |

### floating-note — shipped

| Command id | Title | Status |
|---|---|---|
| `open` | Temporary note | shipped |
| `quick-note` | Throwaway note | planned |
| `note-pin` | Pin note | planned |

### world-clock — shipped

| Command id | Title | Status |
|---|---|---|
| `show` | World clock | shipped |
| `world-overlap` | Meeting overlap helper | planned |

### battery-eta — shipped

| Command id | Title | Status |
|---|---|---|
| `status` | Battery ETA | shipped |

### weather-bar — shipped

| Command id | Title | Status |
|---|---|---|
| `status` | Weather | shipped |

### power-sleep — planned

One power/sleep addon. `power-sleep` opens the list. Absorbs keep-awake and sleep ([0074](tickets.md)). Shipped `keep-awake` keeps its current command ids until this addon is built.

| Command id | Title | Status |
|---|---|---|
| `power-sleep` | Power and sleep | planned |
| `keep-awake` | Keep awake for a duration | planned |
| `stop-keep-awake` | Allow idle sleep again | planned |
| `keep-awake-status` | Whether keep-awake is running | planned |
| `keep-awake-watch` | Keep-awake watcher | planned |
| `sleep-now` | Sleep the Mac | planned |
| `display-sleep` | Sleep displays | planned |

### settings-jump — planned

| Command id | Title | Status |
|---|---|---|
| `jump` | Jump System Settings pane | planned |

### memory-pressure — planned

| Command id | Title | Status |
|---|---|---|
| `show` | Memory pressure + top apps | planned |

### speak-clip — planned

| Command id | Title | Status |
|---|---|---|
| `speak` | Speak clipboard / stop | planned |

### time-machine — planned

| Command id | Title | Status |
|---|---|---|
| `status` | Time Machine status | planned |
| `backup` | Start backup | planned |
| `open` | Open Time Machine | planned |

### notify-clear — planned

| Command id | Title | Status |
|---|---|---|
| `clear` | Clear Notification Center | planned |

### login-items — planned

| Command id | Title | Status |
|---|---|---|
| `open` | Login Items | planned |

### lock-screen — planned

| Command id | Title | Status |
|---|---|---|
| `lock` | Lock screen | planned |

### low-power — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Low Power Mode | planned |

### reminder-add — planned

| Command id | Title | Status |
|---|---|---|
| `add` | Quick-add Reminder | planned |

### next-event — planned

| Command id | Title | Status |
|---|---|---|
| `next` | Next calendar event | planned |

### kitchen-timer — planned

| Command id | Title | Status |
|---|---|---|
| `start` | One-shot countdown | planned |

### audio-output — planned (gap)

| Command id | Title | Status |
|---|---|---|
| `switch` | Switch audio output | planned |

### webcam-mute — planned (gap)

| Command id | Title | Status |
|---|---|---|
| `toggle` | Webcam mute | planned |

### bt-battery — planned (gap)

| Command id | Title | Status |
|---|---|---|
| `show` | AirPods / BT battery | planned |

### kill-hung — planned (gap)

| Command id | Title | Status |
|---|---|---|
| `pick` | Kill hung app | planned |

### disk-pressure — planned (gap)

| Command id | Title | Status |
|---|---|---|
| `show` | Disk pressure | planned |

---

## Security

### password-gen — planned

| Command id | Title | Status |
|---|---|---|
| `generate` | Generate password | planned |
| `password-options` | Passphrase / PIN / options | planned |

---

## Play

Each id is its **own** zip. Shared RNG/timer → **helper**. Session-shaped titles need epic [0059](tickets.md).

| Addon / command id | Title | Status | Lifecycle note |
|---|---|---|---|
| `dice-roll` | Dice roll | planned | oneshot |
| `coin-flip` | Coin flip | planned | oneshot |
| `pick-one` | Pick one | planned | oneshot |
| `number-guess` | Number guess | planned | oneshot |
| `eight-ball` | Magic 8-Ball | planned | oneshot |
| `rps` | Rock–paper–scissors | planned | oneshot |
| `fortune` | Fortune | planned | oneshot |
| `tic-tac-toe` | Tic-tac-toe | planned | oneshot (re-invoke per move) |
| `hangman` | Hangman | planned | session — blocked on 0059 |
| `chess-clock` | Chess clock | planned | session — blocked on 0059 |
| `stopwatch` | Stopwatch | planned | session — blocked on 0059 |
| `memory` | Memory match | planned | session — blocked on 0059 |
| `breathing` | Breathing guide | planned | session — blocked on 0059 |
| `reaction-time` | Reaction time | planned | session — blocked on 0059 |

---

## Design

### sf-symbols — planned

| Command id | Title | Status |
|---|---|---|
| `pick` | Search SF Symbol → copy | planned |

### design-calc — planned

| Command id | Title | Status |
|---|---|---|
| `type-scale` | Type scale | planned |
| `rem-px` | rem ↔ px | planned |
| `aspect-ratio` | Aspect ratio | planned |

### color-eyedropper — planned

| Command id | Title | Status |
|---|---|---|
| `pick` | Eyedropper | planned |
| `color-format` | Hex ↔ rgb/hsl / SwiftUI Color | planned |

### grid-overlay — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Column / baseline overlay | planned |

### emoji-picker — planned

| Command id | Title | Status |
|---|---|---|
| `pick` | Search emoji → copy | planned |

### qr-clip — planned

| Command id | Title | Status |
|---|---|---|
| `encode` | QR generate | planned |
| `decode` | QR scan / decode | planned |

---

## Tools

### unit-convert — planned

| Command id | Title | Status |
|---|---|---|
| `convert` | Convert units | planned |

### calc — planned

Not clip-tools. Future calculator shelf (one zip or split later).

| Command id | Title | Status |
|---|---|---|
| `percentage` | Percentage calculator | planned |
| `age` | Age calculator | planned |
| `emi` | EMI calculator | planned |
| `gpa` | GPA calculator | planned |
| `gst` | GST calculator | planned |

---

## Reference demos

| Addon | Commands | Status |
|---|---|---|
| `ui-demo-confirm` | `demo` | demo |
| `ui-demo-form` | `demo` | demo |
| `ui-demo-list` | `demo` | demo |

---

## Maintenance

When shipping an addon: flip rows to `shipped`, align command ids with `addon.yaml`, and update [catalog-ui.md](catalog-ui.md) if a panel exists. Prefer editing this file over growing parallel lists in chat.
