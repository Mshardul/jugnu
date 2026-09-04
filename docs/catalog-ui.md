# Catalog — UI

Living inventory of **UI mini-apps**: panels / pickers / forms / canvases that one or more [commands](catalog-commands.md) open. Geometry uses shell **view types** only ([view types](architecture/2026-08-24-view-types.md)) — no per-addon pixels.

Companion: [catalog-commands.md](catalog-commands.md). Product rule: every job may expose commands **and/or** popup UI ([vision](vision.md)).

**How to read a row**

| Field | Meaning |
|---|---|
| **Title** | User-facing panel name |
| **Addon** | Owning zip |
| **Opens from** | Command id(s) — one command or a group that shares this surface |
| **View** | Shell view type id (`rows`, `canvas`, `board`, …) or detached (`note` / `toast` / `status`) |
| **Status** | `shipped` / `planned` / `parked` / `draft` |

**Locks (2026-09-04)**

- **Per-family panels**, not one mega Formatter across text + image + PDF + QR.
- **Text Transform** (`clip-tools`) = JSON/CSV/YAML/XML/plain family with type dropdown + auto-detect.
- **PDF Tools** UI is separate from Text Transform.
- **Images** UI is its own family.
- Instant side-effects stay **toast** (or TBD until toast redesign) — no fake empty panel.

---

## Shell (not an addon)

| Title | Opens from | View | Status | Notes |
|---|---|---|---|---|
| Launcher (empty) | hotkey / Open Palette | `seek` | shipped | Search strip |
| Launcher (rows) | hotkey with hits / recents | `palette` | shipped | |
| Browse catalog | Browse Addons | `grid` | shipped | Category / install |
| Addon detail | catalog card | `rail` | shipped | |
| Preferences | Preferences | `rail` | shipped | |
| Confirm | uninstall / destructive | `ask` | shipped | |

---

## Shipped addon UIs

| Title | Addon | Opens from | View | Status | Notes |
|---|---|---|---|---|---|
| Clipboard history | `clipboard-history` | `list` | `rows` | shipped | Filterable history |
| Listening ports | `ports` | `list` | `rows` | shipped | List + kill |
| Brew outdated | `brew-outdated` | `list` | `rows` | shipped | Package list |
| World clock | `world-clock` | `show` | `rows` | shipped | Zones |
| Battery | `battery-eta` | `status` | `rows` | shipped | Glance |
| Weather | `weather-bar` | `status` | `rows` | shipped | Glance |
| Pomodoro setup | `pomodoro` | `work`, `break`, … | `fields` | shipped | Duration / session |
| Keep awake | `keep-awake` | `pick` | `fields` | shipped | Duration picker |
| Nudges manage | `nudges` | `manage`, `advanced`, … | `rows` / `fields` / `ask` | shipped | List + setup + confirm |
| Nudge card | `nudges` | `show-card` / timer fire | `card` (detached) | shipped | Not one of the ten in-panel types |
| Floating note | `floating-note` | `open` | `note` (detached) | shipped | Persist scratchpad |
| Snap board | `window-layouts` | `snap-board` | `board` | shipped | Spatial snaps |
| Zone picker | `window-layouts` | `zone-apply`, `zone-save`, … | `rows` / `fields` / `ask` | shipped | Max 6 zones |
| Confirm demo | `ui-demo-confirm` | `demo` | `ask` | demo | |
| Form demo | `ui-demo-form` | `demo` | `fields` | demo | |
| List demo | `ui-demo-list` | `demo` | `rows` | demo | |

### Toast-only candidates (view TBD)

No browseable content — product pass on toast visual still open ([0052](tickets.md)).

| Title | Addon | Opens from | View | Status |
|---|---|---|---|---|
| Mic mute result | `mic-mute` | `toggle` | toast (TBD) | shipped behavior / undesigned chrome |
| Mute all result | `mute-all` | `toggle` | toast (TBD) | same |
| Focus toggle result | `focus-toggle` | `toggle` | toast (TBD) | same |
| Open terminal | `open-terminal-here` | `open` | toast (TBD) | same |
| Paste plain result | `paste-plain` | `paste` | toast (TBD) | same |

---

## Planned — Clipboard / transform family

### Text Transform

| | |
|---|---|
| **Title** | Text Transform |
| **Addon** | `clip-tools` |
| **Opens from** | `transform` (primary); also deep-links from one-shot commands that offer “Open in Transform” later |
| **View** | `canvas` |
| **Status** | draft (Phase 2) — Phase 1 ships palette one-shots only (`addons/clip-tools`) |
| **Scope** | Paste or edit blob → type dropdown **or auto-detect** (JSON / CSV / YAML / XML / plain) → actions: Format, Minify, Convert (to sibling type), Copy, Replace clipboard. Line tools and case can appear as secondary actions or stay palette-only in v0. |
| **Not in this UI** | PDF, images, QR, calculators, paste-plain (own toast addon) |

### Diff

| | |
|---|---|
| **Title** | Diff |
| **Addon** | `diff` (or mode on `clip-tools` if kept tiny) |
| **Opens from** | `diff-clip` |
| **View** | `spread` |
| **Status** | draft |
| **Scope** | Two panes; compare two buffers / splits. |

### Clipboard guard

| | |
|---|---|
| **Title** | Clipboard Guard |
| **Addon** | `clipboard-guard` |
| **Opens from** | `scan` |
| **View** | `ask` or `rows` |
| **Status** | draft |
| **Scope** | Warn on likely secrets; clear / redact actions. |

---

## Planned — Images

### Image Tools

| | |
|---|---|
| **Title** | Image Tools |
| **Addon** | `images` |
| **Opens from** | dedicated `open` / `studio` command **or** first rich command that needs preview |
| **View** | `canvas` (preview) + `fields` for options |
| **Status** | draft |
| **Scope** | Clipboard or Finder image → resize / crop / compress / rotate / flip / format convert / strip EXIF / favicon. Preview before write. |
| **Parked in UI** | Background remove, upscale — no solid local non-Python path yet. |

---

## Planned — PDF (separate from Text Transform)

### PDF Tools

| | |
|---|---|
| **Title** | PDF Tools |
| **Addon** | `pdf-tools` |
| **Opens from** | `studio` / `open` + per-op commands (`merge`, `split`, …) |
| **View** | `canvas` (page preview) + `rows` (page list / organize) + `fields` (options) |
| **Status** | draft |
| **Scope** | Merge, split, extract, organize, rotate, page numbers, bookmarks, compress, rasterize pages, info, extract text. |
| **Parked** | Word↔PDF, protect, unlock. |
| **OCR** | PDF OCR may open here or hand off to `ocr` — decide at design time. |

---

## Planned — OCR / QR / Design / Tools

| Title | Addon | Opens from | View | Status | Notes |
|---|---|---|---|---|---|
| OCR | `ocr` | `image-text`, `pdf-ocr` | `canvas` | draft | Preview + copy text; language pick later |
| QR | `qr-clip` | `encode`, `decode` | `fields` + preview (`canvas` or inline) | draft | Presets: URL / Wi‑Fi / vCard |
| SF Symbols | `sf-symbols` | `pick` | `grid` | draft | Search → copy name |
| Emoji | `emoji-picker` | `pick` | `grid` | draft | Keep tiny |
| Color | `color-eyedropper` | `pick`, `color-format` | `fields` | draft | Eyedropper + format |
| Design calc | `design-calc` | type-scale / rem-px / … | `fields` | draft | |
| Unit convert | `unit-convert` | `convert` | `fields` | draft | |
| Calculators | `calc` | percentage / age / emi / … | `fields` | draft | Not Text Transform |
| Password | `password-gen` | `generate`, `password-options` | `fields` | draft | |

---

## Planned — other high-traffic panels

| Title | Addon | Opens from | View | Status | Notes |
|---|---|---|---|---|---|
| Process finder | `process-find` | `list`, `find` | `rows` | draft | |
| HTTP probe | `http-status` | `status` | `rows` / `fields` | draft | |
| Hosts blocks | `hosts` | `toggle-block` | `rows` | draft | |
| Meeting join | `meeting-join` | `join`, `meeting-app-pick` | `fields` | draft | |
| Favorite folders | `favorite-folders` | `jump` | `rows` | draft | |
| Recent files | `recent-files` | `list` | `rows` | draft | |
| Screenshot inbox | `screenshot-inbox` | `open`, … | `grid` | draft | |
| World overlap | `world-clock` | `world-overlap` | `board` | draft | |
| Quick note | `floating-note` | `quick-note` | `note` | draft | `persist: false` |

---

## Play UIs

| Title | Addon | View | Status | Notes |
|---|---|---|---|---|
| Dice / coin / 8-ball / … | oneshot Play zips | toast or tiny `ask` | draft | Buildable on oneshot lifecycle |
| Tic-tac-toe | `tic-tac-toe` | `canvas` | draft | Re-invoke per move |
| Hangman / chess-clock / stopwatch / memory / breathing / reaction | session Play | `canvas` | parked | Needs [0059](tickets.md) session + IPC |

---

## Maintenance

When designing a panel: add/update a section here first (title, view, opens-from), then implement. Keep command ids aligned with [catalog-commands.md](catalog-commands.md). Do not invent an eleventh view type until the ten cannot host the job.
