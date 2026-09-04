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

- **`paste-plain`** stays its **own** addon — not absorbed into `clip-tools`.
- **`clip-tools`** = clipboard **text** transforms / formatters only.
- **`python-runtime` helper first**, then `clip-tools` (no in-zip CPython). Specs: [python-runtime](architecture/2026-09-04-python-runtime-helper-design.md) · [clip-tools](architecture/2026-09-04-clip-tools-design.md).
- **PDF** ops live on **`pdf-tools`**, not the text formatter UI.
- **Calculators** (EMI, GPA, GST, %, age, …) stay on the list under **Tools / calc**; not part of clip-tools.
- Heavy / unclear local path (background remover, upscaler, Word↔PDF, protect/unlock PDF) stay **`parked`**, not deleted.

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

### desktop-toggles — planned

| Command id | Title | Status |
|---|---|---|
| `desktop-icons` | Show/hide desktop icons | planned |
| `dock-autohide` | Toggle Dock autohide | planned |
| `menubar-autohide` | Toggle menu bar autohide | planned |

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

### finder-toggles — planned

| Command id | Title | Status |
|---|---|---|
| `hidden-files` | Toggle hidden files | planned |
| `path-bar` | Toggle Finder path bar | planned |
| `status-bar` | Toggle Finder status bar | planned |
| `restart-finder` | Relaunch Finder | planned |

### resolution-preset — planned

| Command id | Title | Status |
|---|---|---|
| `apply` | Apply resolution / HiDPI preset | planned |

---

## Clipboard

### paste-plain — shipped

Own zip. Not part of `clip-tools`.

| Command id | Title | Status |
|---|---|---|
| `paste` | Paste as plain text | shipped |

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

### downloads-triage — planned

| Command id | Title | Status |
|---|---|---|
| `reveal-downloads` | Open Downloads | planned |
| `downloads-age` | Triage by age / type | planned |

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

### screenshot-inbox — planned

| Command id | Title | Status |
|---|---|---|
| `open` | Open screenshot inbox | planned |
| `reveal-latest` | Reveal latest screenshot | planned |
| `archive-latest` | Archive latest | planned |
| `archive-older` | Archive older | planned |

### pdf-tools — planned

Separate from clip-tools / text Transform UI.

| Command id | Title | Status |
|---|---|---|
| `merge` | Merge PDFs | planned |
| `split` | Split PDF | planned |
| `extract-pages` | Extract pages | planned |
| `organize` | Reorder / organize pages | planned |
| `rotate` | Rotate PDF pages | planned |
| `page-count` | Page count | planned |
| `page-numbers` | Add page numbers | planned |
| `bookmarks` | Add / edit bookmarks | planned |
| `info` | PDF info (size, encrypted?, version) | planned |
| `extract-text` | Extract embedded text (non-OCR) | planned |
| `compress` | Compress PDF | planned |
| `jpg-pdf` | JPG → PDF | planned |
| `pdf-jpg` | PDF → JPG | planned |
| `pdf-png` | PDF → PNG | planned |
| `flatten-forms` | Flatten form fields | planned |
| `grayscale` | Grayscale PDF | planned |
| `word-pdf` | Word ↔ PDF | parked |
| `protect` | Protect PDF | parked |
| `unlock` | Unlock PDF | parked |

### large-files — planned

| Command id | Title | Status |
|---|---|---|
| `find` | Biggest files under folder | planned |

### desktop-sweep — planned

| Command id | Title | Status |
|---|---|---|
| `archive` | Archive Desktop clutter | planned |

### mount-dmg — planned

| Command id | Title | Status |
|---|---|---|
| `mount` | Mount DMG / volume | planned |
| `unmount` | Unmount | planned |

### media-convert — planned

| Command id | Title | Status |
|---|---|---|
| `afconvert` | Audio convert presets | planned |

### favorite-folders — planned

| Command id | Title | Status |
|---|---|---|
| `jump` | Jump curated folders | planned |

### recent-files — planned

| Command id | Title | Status |
|---|---|---|
| `list` | Recently modified files | planned |

### scratch-folder — planned

| Command id | Title | Status |
|---|---|---|
| `open` | Open dated Scratch folder | planned |

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

### hosts — planned

| Command id | Title | Status |
|---|---|---|
| `toggle-block` | Enable / disable hosts block | planned |
| `hosts-backup` | Backup / restore hosts | planned |

### ping — planned

| Command id | Title | Status |
|---|---|---|
| `ping` | Ping host | planned |

### http-status — planned

| Command id | Title | Status |
|---|---|---|
| `status` | HTTP status + timing | planned |
| `headers` | Response headers | planned |

### copy-ip — planned

| Command id | Title | Status |
|---|---|---|
| `copy` | Copy LAN / public IP | planned |

### dns-flush — planned

| Command id | Title | Status |
|---|---|---|
| `flush` | Flush DNS | planned |

### proxy-toggle — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | System proxy on/off | planned |

### vpn-connect — planned

| Command id | Title | Status |
|---|---|---|
| `connect` | Named VPN connect / disconnect | planned |

### wifi-toggle — planned

| Command id | Title | Status |
|---|---|---|
| `toggle` | Wi‑Fi off / on / reconnect | planned |

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

### open-url — planned

| Command id | Title | Status |
|---|---|---|
| `open` | Open URL in chosen browser | planned |
| `open-url-profile` | Open in browser profile | planned |

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

### app-info — planned

| Command id | Title | Status |
|---|---|---|
| `front` | Front app info | planned |

### relaunch-app — planned

| Command id | Title | Status |
|---|---|---|
| `relaunch` | Quit + reopen front app | planned |

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

### nudges — shipped

| Command id | Title | Status |
|---|---|---|
| `manage` | Manage nudges | shipped |
| `nudge-now` | Nudge now | shipped |
| `pause` | Pause | shipped |
| `resume` | Resume | shipped |
| `restore-presets` | Restore presets | shipped |
| `advanced` | Advanced | shipped |
| `show-card` | Show card | shipped |

### floating-note — shipped

| Command id | Title | Status |
|---|---|---|
| `open` | Floating scratchpad | shipped |
| `quick-note` | Throwaway note | planned |
| `note-pin` | Pin note | planned |

### world-clock — shipped

| Command id | Title | Status |
|---|---|---|
| `show` | World clock | shipped |
| `world-overlap` | Meeting overlap helper | planned |

### pomodoro — shipped

| Command id | Title | Status |
|---|---|---|
| `work` | Start work | shipped |
| `break` | Start break | shipped |
| `status` | Status | shipped |
| `reset` | Reset | shipped |
| `chime` | Chime | shipped |
| `skip` | Skip / extend / log interruption | planned |

### battery-eta — shipped

| Command id | Title | Status |
|---|---|---|
| `status` | Battery ETA | shipped |

### weather-bar — shipped

| Command id | Title | Status |
|---|---|---|
| `status` | Weather | shipped |

### sleep — planned

| Command id | Title | Status |
|---|---|---|
| `sleep-now` | Sleep Mac | planned |
| `display-sleep` | Sleep displays | planned |

### settings-jump — planned

| Command id | Title | Status |
|---|---|---|
| `jump` | Jump System Settings pane | planned |

### default-browser — planned

| Command id | Title | Status |
|---|---|---|
| `pick` | Default browser | planned |

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
