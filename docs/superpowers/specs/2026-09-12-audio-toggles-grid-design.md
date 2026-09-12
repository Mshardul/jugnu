# `audio-toggles` addon + first `grid` view-type content contract

**Date:** 2026-09-12
**Status:** Draft — pending review
**Tickets:** [0074](../../tickets.md) (addon clubbing — Audio merge), amends [0068 §7](../../architecture/2026-08-24-view-types.md) (`mic-mute`/`mute-all` TBD row)
**Depends on:** [view types](../../architecture/2026-08-24-view-types.md), [addon process lifecycle](../../architecture/2026-08-30-addon-process-lifecycle-design.md) (`oneshot` class, unchanged by this work)

## 1. Intent

Merge `jugnu.mic-mute` + `jugnu.mute-all` into one addon, `jugnu.audio-toggles`, per the domain-grouping decision locked in [0074](../../tickets.md). This is also the **first real consumer of the `grid` view type** — `grid` has existed in the geometry catalog since 0045 but no addon has ever emitted grid content, so this spec also defines the missing shell-side content contract (`UIPattern.grid` + `UIGridItem` + `GridPanelView`), following the same pattern `rows`/`UIListItem`/`ListPanelView` already established.

This supersedes the "likely toast-only" guess for `mic-mute`/`mute-all` in [view-types §7](../../architecture/2026-08-24-view-types.md#7-per-addon-view-type-assignment--locked-2026-08-26) — the merged addon needs a real panel (live status + tap-to-toggle for two-plus tiles), not a toast.

## 2. Addon shape

Replaces `jugnu.mic-mute` and `jugnu.mute-all` outright — both addons deleted, no deprecation stub (single-publisher catalog today, nothing external depends on the old ids; AGENTS.md's "decide for the long-term end-state" rules out keeping three audio addons around).

```yaml
id: jugnu.audio-toggles
name: Audio
version: 1.0.0
api: 1
view_types: [grid]
commands:
  - id: audio-toggles
    title: Audio
    subtitle: Mic and mute-all status — tap to toggle
    keywords: [audio, mic, mute, speaker, volume]
    view: grid
  - id: mute-mic
    title: Toggle microphone mute
    subtitle: Mute or unmute input
    keywords: [mic, mute, audio]
  - id: mute-all
    title: Mute all
    subtitle: Mute mic and speakers, or restore the previous volumes
    keywords: [mute, mic, speaker, volume, meeting]
entrypoint:
  kind: exec
  path: bin/run
cleanup:
  paths:
    - "~/.local/share/jugnu/state/audio-toggles"
  launchd: []
```

Command-id naming: `audio-toggles` (not bare `open`), `mute-mic`/`mute-all` (domain-qualified, not bare `toggle`) — per 0074's naming-convention note.

`mute-mic` and `mute-all` command bodies are unchanged logic from today's `jugnu.mic-mute`/`jugnu.mute-all` `bin/run` scripts (same osascript, same instant-toast behavior) — only relocated into the merged addon and (for `mute-all`) pointed at the new state dir `~/.local/share/jugnu/state/audio-toggles`. No migration of the old `.../state/mute-all/volumes` file — fresh start; worst case one stale saved-volumes entry sits unrestored in the deleted addon's old (now-orphaned) state dir, which is harmless.

### 2.1 Entrypoint dispatch — first multi-command bash addon

Every existing bash-based addon (`mic-mute`, `mute-all`, ...) is single-command and discards the whole stdin request. This is the **first bash addon needing command dispatch** (window-layouts also has multiple commands but routes internally inside a compiled Swift helper, not bash). No jq/JSON-parsing precedent exists in any addon script today, and jq is not a documented/guaranteed dependency for addon scripts — so dispatch uses a dependency-free grep/sed extraction, matching the crude-but-working string handling `mute-all`'s own script already uses (its `is_volume` regex check):

```
addons/jugnu.audio-toggles/
  addon.yaml
  bin/
    run                    # thin router: extracts "command" field, execs the matching script
    mute-mic                # today's mic-mute logic, unchanged
    mute-all                 # today's mute-all logic, unchanged (new state dir)
    audio-toggles-status      # reads live mic + mute-all state, emits grid JSON
```

`bin/run`:

```bash
#!/bin/bash
set -euo pipefail
request=$(cat)
root="$(cd "$(dirname "$0")" && pwd)"
command=$(printf '%s' "$request" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/^"command"[[:space:]]*:[[:space:]]*"([^"]*)"$/\1/')

case "$command" in
  audio-toggles) printf '%s' "$request" | exec "$root/audio-toggles-status" ;;
  mute-mic)      printf '%s' "$request" | exec "$root/mute-mic" ;;
  mute-all)      printf '%s' "$request" | exec "$root/mute-all" ;;
  *) echo '{"ok":false,"error":"Unknown command"}'; exit 0 ;;
esac
```

Each subscript keeps reading/discarding stdin exactly like today's single-command scripts (they don't need `command` themselves — `bin/run` already resolved it). This is the same "one entrypoint, internal dispatch" shape `window-layouts` uses, just in bash instead of compiled Swift — no new file format, no separate mapping file, nothing to keep in sync elsewhere.

## 3. Grid content contract (new shell protocol)

Mirrors `UIListItem`/`ListPanelView`, the existing pattern for `rows`/`board`, adding an icon + active-state pair that list items don't carry:

```swift
// JugnuCore/Protocol/RunModels.swift
public enum UIPattern: String, Codable, Sendable, Equatable {
    case list
    case form
    case confirm
    case note
    case card
    case grid   // NEW
}

public struct UIGridItem: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var icon: String        // SF Symbol name
    public var active: Bool        // current live state — filled/accent vs outline
    public var actions: [String]?  // same follow-up-action convention as UIListItem
}

// UIDescriptor gains:
public var gridItems: [UIGridItem]?
```

`UIPattern.grid`'s default view type is `.grid` (parallel to `.list` → `.rows`, per `UIPattern.defaultViewType`); a command can still override with `view: grid` explicitly as shown above for clarity.

Example `audio-toggles` command response:

```json
{
  "ok": true,
  "ui": {
    "pattern": "grid",
    "title": "Audio",
    "gridItems": [
      {"id": "mic", "title": "Microphone", "icon": "mic.fill", "active": false, "actions": ["mute-mic"]},
      {"id": "all", "title": "Mute All", "icon": "speaker.slash.fill", "active": true, "actions": ["mute-all"]}
    ]
  }
}
```

## 4. Rendering + interaction

New `GridPanelView` (parallel file to `ListPanel.swift`) renders `gridItems` in a `LazyVGrid`, one tile per item: icon (SF Symbol), title, `active` state shown as filled/accent tile vs outline tile (matches Control Center tile convention referenced in 0074). Tapping a tile behaves exactly like `ListPanelView.onSelect` — posts `itemId` + first `actions` entry as a follow-up run request; `ShellHost` gets a new `.grid` case in its pattern-dispatch switch (`renderFollowUpContent`) alongside the existing `.list`/`.form`/`.confirm`/`.note`/`.card` arms, rendering `GridPanelView`. No optimistic local state flip — the follow-up round-trip re-invokes `bin/run`, which re-reads live OS state (mic mute via `input volume of (get volume settings) == 0`, mute-all-active via presence of the state file) and returns a fresh `gridItems` array reflecting reality regardless of which command last changed it. This is the same mechanism `rows`/`board` already use; no new shell-side state-reconciliation logic.

## 5. Error handling

Unchanged from existing `mic-mute`/`mute-all` scripts: `osascript` failures already return `{"ok": false, "error": "..."}` and surface via the existing `PanelErrorBanner` path — no new error shape needed since `audio-toggles`' grid-render command only reads state (read failures are the same "Could not read volume" case `mute-all` already handles) and delegates actual state changes to the two direct commands, which keep their existing failure handling.

## 6. Testing

- `swift test`: new `UIGridItem`/`UIPattern.grid` codable round-trip tests (parallel to existing `UIListItem` tests), `ViewType.resolve` default-mapping test for `.grid` pattern, `GridPanelView` tap → follow-up-args test (parallel to existing `ListPanelView` test).
- Addon-side: adapt existing `jugnu.mute-all/tests` to the merged addon's `bin/run`, covering `mute-mic`/`mute-all`/`audio-toggles` (state-read) paths.
- `scripts/validate-addon.sh` must accept the new manifest (`view_types: [grid]`, three commands, no `view:` per-command needed for the two direct commands since they have no content response).
- Manual: shell-smoke walk of the new grid panel (tap-to-toggle both tiles, confirm live-state sync regardless of entry point).

## 7. Out of scope

- Real spatial/2D layout for `grid` (this ticket's grid is a flat icon gallery, same "landscape aspect, not actually spatial" honesty `board` already established — see finding that `board` today is `list` content in a wider frame).
- Any change to `board`'s existing list-based implementation.
- Migrating `mute-all`'s saved-volumes state file from the old addon's state dir.
- Deprecation stubs for `jugnu.mic-mute` / `jugnu.mute-all` ids.
- Growing `audio-toggles`' grid beyond the two current tiles (0074 notes it "grows as more audio commands ship" — future tiles are additive, not designed here).
