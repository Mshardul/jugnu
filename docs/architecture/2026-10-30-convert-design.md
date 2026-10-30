# Jugnu — Convert (file + text)

**Date:** 2026-10-30  
**Status:** Draft — product locked 2026-10-30. Frame-independent Core + clip-tools slice implemented; UI blocks and the `jugnu.convert` addon wait on the app frame  
**Ticket:** [0079](../tickets.md)  
**Depends on:** [App shell plan](./2026-10-12-app-shell-design.md) (§2 frame, §11.1 single view; delivery phase 3), [Addon UI + speed](./2026-08-22-addon-ui-speed-design.md), [Addon manifest](../addon-manifest.md), [Process lifecycle](./2026-08-30-addon-process-lifecycle-design.md) (`oneshot`)  
**Supersedes:** the *Text Transform* panel sketched in [clip-tools design §5](./2026-09-04-clip-tools-design.md) and the *File conversion* panel planned under `pdf-tools` in [catalog-ui](../catalog-ui.md). Both fold into this design.  
**Not this spec:** unit conversion (`unit-convert`), calculators, OCR, `session` IPC ([0059](../tickets.md)).

## 1. Job

Turn one format into another without learning which addon owns the converter. Two commands, two content blocks:

| Command | Content block | Input | Output |
|---|---|---|---|
| `convert-file` | File converter | A file: picked, dropped, or copied in Finder / on the clipboard | A new file |
| `convert-text` | Text converter | Text: clipboard or typed | Text, shown live beside the input |

Converters stay where they are (`clip-tools`, `images`, `pdf-tools`, `media-convert`, …). Nothing is reimplemented.

### Hosting: the single view

Both blocks live in the **stable app frame** (app shell plan §2, §11.1), the same frame as Catalog, Home and Preferences. They are not view-type panels: no `fields`, no `spread`, no panel resize. Opening a command from Home, Search or the Catalog keeps the frame and renders the block in the content pane; closing it returns to the section the user left.

This is the direction for all addon UI: the frame is the one view and everything migrates into it. Convert is new, so it is built in the frame from the start and never ships a view-type presentation that would need migrating later. Size follows the shell rule: the file block is compact (it is a short form); the text block uses the room (two panes).

## 2. Locked product

### `convert-file`

- Drop zone plus a *Choose file…* button; opens pre-filled when invoked with a Finder selection or a file on the clipboard.
- Detected input format is shown. **Output** dropdown lists only formats reachable from it (§4).
- *Convert* writes a new file **beside the original**. Never overwrites: an existing name gets a numeric suffix. Result is a row with *Reveal* and *Copy path*.
- Clipboard image data (no file behind it) is written to a temp file first; its output goes to `~/Downloads`.
- The drop zone accepts a list. All files must share one detected format; a mixed drop shows a plain-language error. Files convert in order.

### `convert-text`

- Left pane: input (editable). Right pane: output, divided by a vertical partition.
- **Input format:** auto-detected, with an override dropdown (default *Auto*). The detected format is shown while *Auto* is selected.
- **Output format:** dropdown, filtered by the input format.
- Opens with clipboard text if present, else empty.
- Output re-renders as the input or either dropdown changes (§6).
- Output pane is **read-only by default**. Three controls on it:
  - **Copy** — copies the output pane's current text.
  - **Download** — saves a new file to `~/Downloads` with the output format's extension. Never overwrites (numeric suffix). Reveals it after saving.
  - **Lock** — icon-only toggle (not a radio button), on by default. Off makes the output pane editable. Edits are never converted back; Copy and Download use the edited text. Changing the input or either dropdown while unlocked asks before replacing edits.
- Invalid input shows an inline message in the output pane (plain language, from the converter's `error`), never a stack trace. Output keeps the last good value dimmed.
- Text only. Binary families (images, PDF, audio) are file-block only.

## 3. Packaging

New first-party addon **`convert`**, category **Tools**. It owns two commands and no converter code. Its entrypoint is `kind: shell`: both commands open shell-hosted content blocks and run no addon process. If the manifest and validator do not yet allow an addon with no `exec` entrypoint, that is part of this work.

Converters are provided by the addons that already own the format work, via the manifest field in §4. An addon that declares converters does not depend on `convert`; `convert` does not depend on them. Uninstall a converter addon and its routes disappear from the dropdowns. Install `convert` alone and both blocks open with nothing to convert, saying so.

## 4. Manifest: `converters`

Addons declare what they can convert; the shell builds the graph.

```yaml
converters:
  - command: json-csv      # existing command id on this addon
    from: json
    to: csv
    modes: [text]          # any of: text, file
  - command: heic-jpeg
    from: heic
    to: jpeg
    modes: [file]
```

- `from` / `to` are **format ids**. The shell owns a core **format catalog** (id, label, extensions, UTType, sniff rule). Addons may add formats with a `formats:` block (id, label, extensions, mime, optional magic/regex sniff). A format id already in the catalog cannot be redefined.
- One entry is one directed edge. The output dropdown for input `X` is every `to` reachable by **one edge** from `X`. No multi-hop chaining: chaining hides cost and failure modes. If a two-step route is wanted, the owning addon declares it as one edge.
- Two addons declaring the same edge: the shell offers a chooser only if both are enabled; the order is the user's addon order. Same-edge duplicates never hide each other silently.
- `modes` is a list of `text` and/or `file` (at least one) and decides which block lists the edge. A `text` edge needs text in and text out; a `file` edge needs a path in and a path out.

### Invocation

Reuses the existing stdin/stdout protocol, one new op:

```json
{"api":1,"op":"convert","command":"json-csv","from":"json","to":"csv","text":"…"}
→ {"ok":true,"text":"…"}  |  {"ok":false,"error":"…"}

{"api":1,"op":"convert","command":"heic-jpeg","from":"heic","to":"jpeg","path":"/in/a.heic","out":"/out/a.jpg"}
→ {"ok":true,"path":"/out/a.jpg"}
```

The shell chooses `out` (collision-free) so the addon never decides where files land. For `clip-tools` the existing op functions are reused through a clipboard-free path; the router gains a seam beside `RAW_READ_COMMANDS` so no second engine exists.

## 5. Detection

- **File:** extension and UTType via the catalog, then magic bytes when the extension is missing or disagrees.
- **Text:** ordered catalog sniffers, strict before loose: JSON → XML → CSV/TSV (consistent delimiter and column count) → YAML → plain. Ambiguous text resolves to the most specific format that parses; the override dropdown exists because this can be wrong.
- Detection runs in the shell, cheap, on the input pane's current text; it never spawns an addon.

## 6. Live conversion and speed

`oneshot` per conversion. No long-lived process (that would be `session`, [0059](../tickets.md)).

- **Debounce** ~150 ms after the last change; a conversion in flight when new input arrives is cancelled (**latest wins**). A stale result never overwrites a newer one.
- Output shows `progress` per the UI + speed design if a conversion exceeds the chrome budget.
- Input beyond a size cap skips live mode and converts on an explicit *Convert* press; the cap is a shell constant, measured, not an addon field.
- **Acceptance gate:** measured end-to-end (keystroke → output painted) on a typical clip-tools conversion must meet the *follow-up action → feedback* budget (≤150 ms target, 400 ms ceiling, UI + speed §6). If the python-runtime path cannot, the fix is in the converter's startup, not a weaker view.

## 7. Shell work

| Piece | Notes |
|---|---|
| Frame route | `convert-file` and `convert-text` are routes in the shared frame (app shell plan §2, §11.1). Requires delivery phase 3 (shared large frame). |
| File block | Drop zone (file, list), detected-format line, output dropdown, result rows. Built from shared primitives. |
| Text block | Two panes with a vertical partition, per-pane toolbar, dropdowns. The same pane shell serves Diff later. |
| No view type | Neither block is a view-type panel; nothing here adds to or uses the ten. |
| Manifest | `converters:`, `formats:`, `entrypoint: kind: shell`; validator + `validate-addon.sh` rules. |
| Format catalog + detection | Shell-owned; unit-tested with fixture inputs. |
| Convert router | Builds the edge graph from enabled addons; rebuilt on enable/disable. |
| Output writer | Collision-free naming, Downloads/beside-original rules, temp cleanup. |

## 8. Addon work

| Addon | Converters declared |
|---|---|
| `clip-tools` | json↔csv, json↔yaml, xml→json, csv↔markdown-table, and the other same-shape text converters already shipped (add `converters:` plus the `convert` op; no new logic). |
| `images` / `pdf-tools` / `media-convert` | Declare edges as each ships (heic→jpeg, jpeg↔pdf, pdf→png, audio presets). Not a blocker for v1. |
| `convert` | New. Two commands, `kind: shell` entrypoint. |

## 9. Catalog and doc changes this implies

- [catalog-ui](../catalog-ui.md): *Text Transform* and *File conversion (pdf-tools)* are superseded by *Convert*.
- [catalog-commands](../catalog-commands.md): `transform` (clip-tools) is dropped; `convert` (pdf-tools) becomes the `convert` addon's two commands. `unit-convert` keeps its own `convert` id — rename to a job-named id when that addon is built (naming rule in [addon-manifest](../addon-manifest.md#required-fields)).
- Finder right-click **Convert** (pdf-tools plan) opens `convert-file` with the file filled in.
- The *View* rows for these panels in catalog-ui are replaced by "content block in the frame" (§ Hosting).

## 10. Success criteria

1. `convert-file`: dropping a `.json` offers csv/yaml; converting writes a collision-free file beside the original; uninstalling the converter addon removes the options.
2. `convert-text`: typing in the left pane updates the right within the speed gate; invalid JSON shows an inline message, last good output dimmed.
3. Lock toggle, Copy and Download behave as §2, including overwrite protection.
4. Edge graph, detection, and output naming have unit tests; both blocks have entries in [shell-smoke](./shell-smoke.md).
5. `validate-addon.sh` passes for `convert` and for `clip-tools` with `converters:`.

## 11. Non-goals

- Multi-hop conversion chains.
- Converting back from edited output.
- Binary formats in the text block.
- Third-party-authored format sniffers beyond declarative magic/regex.
