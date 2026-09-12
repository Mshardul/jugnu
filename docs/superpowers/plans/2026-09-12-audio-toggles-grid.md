# Audio Toggles + Grid View-Type Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `jugnu.mic-mute` + `jugnu.mute-all` into one new addon `jugnu.audio-toggles`, and add the shell's first `grid` view-type content contract (`UIPattern.grid`, `UIGridItem`, `GridPanelView`) so the merged addon's status panel can render two live-state, tap-to-toggle icon tiles.

**Architecture:** Shell-side: add a `grid` case alongside the existing `list`/`form`/`confirm` pattern machinery in `JugnuCore` (protocol) and `JugnuUI` (rendering + `ShellHost` dispatch) — mirrors the existing `list`/`UIListItem`/`ListPanelView` triplet exactly. Addon-side: new `jugnu.audio-toggles` addon with a thin bash router (`bin/run`) dispatching by `command` field to three subscripts; old `jugnu.mic-mute`/`jugnu.mute-all` addons deleted outright, no deprecation stub, no state migration.

**Tech Stack:** Swift (SwiftUI, XCTest) for the shell; Bash + osascript for the addon; Python (pytest) for addon tests, matching the existing `jugnu.mute-all/tests` pattern.

**Spec:** [docs/superpowers/specs/2026-09-12-audio-toggles-grid-design.md](../specs/2026-09-12-audio-toggles-grid-design.md)

## Global Constraints

- Command ids: `audio-toggles`, `mute-mic`, `mute-all` — no bare `open`/`toggle` ids (spec §2, ticket 0074).
- New addon replaces old ones outright — delete `addons/jugnu.mic-mute` and `addons/jugnu.mute-all` entirely, no stub/redirect.
- No migration of `mute-all`'s old state file; new state dir is `~/.local/share/jugnu/state/audio-toggles`.
- No jq or any new external dependency in addon bash scripts — grep/sed only (spec §2.1).
- Grid tap-to-toggle uses the existing follow-up round-trip mechanism (`ShellHost.submitFollowUp`) — no optimistic local state, no new state-reconciliation code.
- `UIGridItem` fields: `id: String`, `title: String`, `subtitle: String?`, `icon: String` (SF Symbol name), `active: Bool`, `actions: [String]?`.
- `UIPattern.grid`'s `defaultViewType` is `.grid` (parallel to `.list` → `.rows`).

---

## Task 1: `UIPattern.grid` + `UIGridItem` protocol types

**Files:**
- Modify: `shell/Sources/JugnuCore/Protocol/RunModels.swift`
- Test: `shell/Tests/JugnuCoreTests/RunModelsTests.swift`

**Interfaces:**
- Produces: `UIPattern.grid` case; `UIGridItem` struct (`id: String`, `title: String`, `subtitle: String?`, `icon: String`, `active: Bool`, `actions: [String]?`); `UIDescriptor.gridItems: [UIGridItem]?` property.

- [ ] **Step 1: Write the failing test**

Add to `shell/Tests/JugnuCoreTests/RunModelsTests.swift`:

```swift
    func testGridResponseRoundTrip() throws {
        let json = Data("""
        {"ok":true,"ui":{"pattern":"grid","title":"Audio","gridItems":[
          {"id":"mic","title":"Microphone","icon":"mic.fill","active":false,"actions":["mute-mic"]},
          {"id":"all","title":"Mute All","icon":"speaker.slash.fill","active":true,"actions":["mute-all"]}
        ]}}
        """.utf8)
        let decoded = try JSONDecoder().decode(RunResponse.self, from: json)
        XCTAssertEqual(decoded.ui?.pattern, .grid)
        XCTAssertEqual(decoded.ui?.gridItems?.count, 2)
        XCTAssertEqual(decoded.ui?.gridItems?.first?.id, "mic")
        XCTAssertEqual(decoded.ui?.gridItems?.first?.icon, "mic.fill")
        XCTAssertEqual(decoded.ui?.gridItems?.first?.active, false)
        XCTAssertEqual(decoded.ui?.gridItems?.last?.active, true)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter RunModelsTests/testGridResponseRoundTrip`
Expected: FAIL — `UIPattern` has no member `grid`, `UIDescriptor` has no member `gridItems`.

- [ ] **Step 3: Write minimal implementation**

In `shell/Sources/JugnuCore/Protocol/RunModels.swift`, add `case grid` to `UIPattern`:

```swift
public enum UIPattern: String, Codable, Sendable, Equatable {
    case list
    case form
    case confirm
    case note
    case card
    case grid
}
```

Add the new struct after `UIListItem`:

```swift
public struct UIGridItem: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var icon: String
    public var active: Bool
    public var actions: [String]?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        active: Bool,
        actions: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.active = active
        self.actions = actions
    }
}
```

Add `gridItems` to `UIDescriptor` (property, init parameter with default `nil`, matching the existing `items`/`fields` placement):

```swift
public struct UIDescriptor: Codable, Sendable, Equatable {
    public var pattern: UIPattern
    public var title: String?
    public var placeholder: String?
    public var message: String?
    public var items: [UIListItem]?
    public var gridItems: [UIGridItem]?
    public var fields: [UIFormField]?
    public var confirmLabel: String?
    public var cancelLabel: String?
    public var content: String?
    public var emoji: String?
    public var accent: String?
    public var view: ViewType?

    public init(
        pattern: UIPattern,
        title: String? = nil,
        placeholder: String? = nil,
        message: String? = nil,
        items: [UIListItem]? = nil,
        gridItems: [UIGridItem]? = nil,
        fields: [UIFormField]? = nil,
        confirmLabel: String? = nil,
        cancelLabel: String? = nil,
        content: String? = nil,
        emoji: String? = nil,
        accent: String? = nil,
        view: ViewType? = nil
    ) {
        self.pattern = pattern
        self.title = title
        self.placeholder = placeholder
        self.message = message
        self.items = items
        self.gridItems = gridItems
        self.fields = fields
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
        self.content = content
        self.emoji = emoji
        self.accent = accent
        self.view = view
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter RunModelsTests/testGridResponseRoundTrip`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add shell/Sources/JugnuCore/Protocol/RunModels.swift shell/Tests/JugnuCoreTests/RunModelsTests.swift
git commit -m "feat: add UIPattern.grid and UIGridItem protocol types"
```

---

## Task 2: `ViewType.grid` default mapping + resolve test

**Files:**
- Modify: `shell/Sources/JugnuCore/ViewType.swift`
- Test: `shell/Tests/JugnuCoreTests/ViewTypeTests.swift`

**Interfaces:**
- Consumes: `UIPattern.grid` (Task 1).
- Produces: `UIPattern.defaultViewType` returns `.grid` for `.grid` pattern (parallel to `.list` → `.rows`).

- [ ] **Step 1: Write the failing test**

Add to `shell/Tests/JugnuCoreTests/ViewTypeTests.swift`:

```swift
    func testResolveUsesGridDefaultWhenRequestOmitted() throws {
        XCTAssertEqual(
            try ViewType.resolve(pattern: .grid, requested: nil, allowed: [.grid]),
            .grid
        )
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ViewTypeTests/testResolveUsesGridDefaultWhenRequestOmitted`
Expected: FAIL — `ViewType.resolve` returns `nil` for `.grid` pattern since `UIPattern.defaultViewType` has no `.grid` case yet (falls into no matching case; today it would not compile since the switch is exhaustive on cases that exist — see Step 3).

- [ ] **Step 3: Write minimal implementation**

In `shell/Sources/JugnuCore/ViewType.swift`, update the `UIPattern.defaultViewType` extension:

```swift
public extension UIPattern {
    var defaultViewType: ViewType? {
        switch self {
        case .list: .rows
        case .form: .fields
        case .confirm: .ask
        case .grid: .grid
        case .note, .card: nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ViewTypeTests/testResolveUsesGridDefaultWhenRequestOmitted`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add shell/Sources/JugnuCore/ViewType.swift shell/Tests/JugnuCoreTests/ViewTypeTests.swift
git commit -m "feat: map UIPattern.grid to ViewType.grid by default"
```

---

## Task 3: `ShellViewState.grid` + `ShellPreset.grid`

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellStack.swift`
- Modify: `shell/Sources/JugnuUI/ShellPreset.swift`
- Test: `shell/Tests/JugnuUITests/ShellHostFrameTests.swift`

**Interfaces:**
- Consumes: `ViewType.grid` (Task 2).
- Produces: `ShellViewState.grid(highlightedID: String?)` case; `ShellPreset.grid` case with `defaultViewType(compactLauncher:) -> .grid`.

- [ ] **Step 1: Write the failing test**

First read the existing `ShellHostFrameTests.swift` to match its exact test style:

```bash
sed -n '1,60p' shell/Tests/JugnuUITests/ShellHostFrameTests.swift
```

Then add a test asserting `ShellPreset.grid.defaultViewType(compactLauncher:)` returns `.grid` regardless of `compactLauncher`:

```swift
    func testGridPresetDefaultsToGridViewType() {
        XCTAssertEqual(ShellPreset.grid.defaultViewType(compactLauncher: false), .grid)
        XCTAssertEqual(ShellPreset.grid.defaultViewType(compactLauncher: true), .grid)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd shell && swift test --filter ShellHostFrameTests/testGridPresetDefaultsToGridViewType`
Expected: FAIL — `ShellPreset` has no member `grid`.

- [ ] **Step 3: Write minimal implementation**

In `shell/Sources/JugnuUI/ShellPreset.swift`:

```swift
public enum ShellPreset: String, Equatable, Sendable {
    case launcher
    case catalog
    case settings
    case detail
    case confirm
    case list
    case form
    case grid

    public func defaultViewType(compactLauncher: Bool) -> ViewType {
        switch self {
        case .launcher: compactLauncher ? .seek : .palette
        case .catalog: .canvas
        case .settings, .detail: .canvas
        case .confirm: .ask
        case .list: .rows
        case .form: .fields
        case .grid: .grid
        }
    }

    public func size(
        compactLauncher: Bool,
        visibleFrame: NSRect = NSRect(x: 0, y: 0, width: 1440, height: 900)
    ) -> NSSize {
        let box = defaultViewType(compactLauncher: compactLauncher).size(in: visibleFrame)
        return NSSize(width: box.width, height: box.height)
    }

    public var hasSidebar: Bool {
        self == .catalog
    }
}
```

In `shell/Sources/JugnuUI/ShellStack.swift`, add a `.grid` case to `ShellViewState` (mirrors `.list`'s single-purpose payload — grid needs only a highlight, no query/scroll since it isn't filterable):

```swift
public enum ShellViewState: Equatable, Sendable {
    case launcher(query: String, selection: String?, scroll: CGFloat)
    case catalog(
        category: String?,
        subcategory: String?,
        tags: Set<String>,
        query: String,
        scroll: CGFloat,
        selectedCardID: String?
    )
    case settings(scroll: CGFloat, focusedControlID: String?)
    case detail(addonID: String, tab: AddonDetailTab = .overview)
    case confirm
    case list(query: String, highlightedID: String?, scroll: CGFloat)
    case form(values: [String: String], focusedFieldID: String?)
    case grid(highlightedID: String?)

    public var preset: ShellPreset {
        switch self {
        case .launcher: .launcher
        case .catalog: .catalog
        case .settings: .settings
        case .detail: .detail
        case .confirm: .confirm
        case .list: .list
        case .form: .form
        case .grid: .grid
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd shell && swift test --filter ShellHostFrameTests/testGridPresetDefaultsToGridViewType`
Expected: PASS

- [ ] **Step 5: Run full shell test suite to confirm no exhaustive-switch breakage elsewhere**

Run: `cd shell && swift build 2>&1 | tail -50`
Expected: build succeeds — if it fails on a non-exhaustive switch over `ShellPreset` or `ShellViewState` outside the files touched so far, add the missing `.grid` arm at that call site before proceeding (check `ShellHost.swift`'s `pushFollowUp`/`renderFollowUpContent` switches — those are handled in Task 5, so a build failure pointing there is expected until Task 5 lands; if it points anywhere else, fix it here).

- [ ] **Step 6: Commit**

```bash
git add shell/Sources/JugnuUI/ShellStack.swift shell/Sources/JugnuUI/ShellPreset.swift shell/Tests/JugnuUITests/ShellHostFrameTests.swift
git commit -m "feat: add grid case to ShellViewState and ShellPreset"
```

---

## Task 4: `GridPanelView` SwiftUI component

**Files:**
- Create: `shell/Sources/JugnuUI/GridPanel.swift`

**Interfaces:**
- Consumes: `UIDescriptor.gridItems: [UIGridItem]?` (Task 1), `PanelErrorState`, `JugnuTheme`/`ThemeStore`/`JugnuTokens` (existing, see `ListPanel.swift` for exact usage).
- Produces: `GridPanelView` — `init(ui: UIDescriptor, errorState: PanelErrorState, onSelect: @escaping (UIGridItem, String?) -> Void, onCancel: @escaping () -> Void)`.

- [ ] **Step 1: Write the component**

No unit test for this step — `ListPanelView` (its direct precedent) has no dedicated test file either; SwiftUI view correctness here is validated by the manual shell-smoke walk in Task 8. Create `shell/Sources/JugnuUI/GridPanel.swift`:

```swift
import AppKit
import JugnuCore
import SwiftUI

public struct GridPanelView: View {
    let ui: UIDescriptor
    @ObservedObject var errorState: PanelErrorState
    var onSelect: (UIGridItem, String?) -> Void
    var onCancel: () -> Void

    @Environment(\.jugnuTheme) private var theme
    @ObservedObject private var store = ThemeStore.shared

    public init(
        ui: UIDescriptor,
        errorState: PanelErrorState,
        onSelect: @escaping (UIGridItem, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.ui = ui
        self.errorState = errorState
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    private var items: [UIGridItem] {
        ui.gridItems ?? []
    }

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: JugnuTokens.Spacing.row)]

    public var body: some View {
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            Text(ui.title ?? "Audio")
                .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
            if let message = errorState.message {
                PanelErrorBanner(message: message)
            }
            LazyVGrid(columns: columns, spacing: JugnuTokens.Spacing.row) {
                ForEach(items, id: \.id) { item in
                    Button {
                        onSelect(item, item.actions?.first ?? "select")
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(item.active ? theme.accent : theme.textSecondary)
                            Text(item.title)
                                .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                                .foregroundStyle(theme.textPrimary)
                            if let subtitle = item.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.active ? theme.accent.opacity(0.15) : theme.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(item.active ? theme.accent : theme.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}
```

Check `theme.textPrimary` exists on the theme type used by `ListPanelView` — if the actual property name differs (e.g. `theme.text`), grep first:

```bash
grep -n "textPrimary\|textSecondary\|var text" shell/Sources/JugnuUI/*.swift | grep -i theme | head -10
```

Adjust the property name in the view above to match whatever `JugnuTheme` actually exposes before building.

- [ ] **Step 2: Build to verify it compiles**

Run: `cd shell && swift build 2>&1 | tail -50`
Expected: builds clean (fix any property-name mismatches found in Step 1's grep).

- [ ] **Step 3: Commit**

```bash
git add shell/Sources/JugnuUI/GridPanel.swift
git commit -m "feat: add GridPanelView for grid-pattern UI content"
```

---

## Task 5: Wire `grid` into `ShellHost` dispatch

**Files:**
- Modify: `shell/Sources/JugnuUI/ShellHost.swift`

**Interfaces:**
- Consumes: `ShellViewState.grid` (Task 3), `GridPanelView` (Task 4), `UIPattern.grid` (Task 1).
- Produces: `ShellHost.pushFollowUp` and `ShellHost.renderFollowUpContent` handle `.grid` the same way they handle `.list`.

- [ ] **Step 1: Update `pushFollowUp`'s pattern switch**

In `shell/Sources/JugnuUI/ShellHost.swift`, `pushFollowUp` method, extend the switch:

```swift
        let state: ShellViewState
        switch ui.pattern {
        case .confirm: state = .confirm
        case .list: state = .list(query: "", highlightedID: nil, scroll: 0)
        case .form: state = .form(values: [:], focusedFieldID: nil)
        case .grid: state = .grid(highlightedID: nil)
        case .note: return // note is detached, not a stack push
        case .card: return
        }
```

- [ ] **Step 2: Update `renderFollowUpContent`'s preset switch**

In the same file, `renderFollowUpContent` method, add a `.grid` case parallel to `.list` (same `submitFollowUp` args shape — `itemId` + first action):

```swift
        case .grid:
            setContent(GridPanelView(
                ui: ui,
                errorState: followUpError,
                onSelect: { [weak self] item, action in
                    var args: [String: JSONValue] = ["itemId": .string(item.id)]
                    if let action {
                        args["action"] = .string(action)
                    }
                    self?.submitFollowUp(args: args)
                },
                onCancel: { [weak self] in self?.cancelFollowUp() }
            ))
```

Insert it alongside the existing `.list` case (order doesn't matter, switch is exhaustive over `ShellPreset` values that reach this point — `.launcher`/`.catalog`/`.settings`/`.detail` never reach `renderFollowUpContent` since they're not follow-up states, so the `default: break` still covers them).

- [ ] **Step 3: Update `present`'s pattern guard**

In `ShellHost.present`, the top-level guard currently reads `if let ui = response.ui, ui.pattern != .note, ui.pattern != .card`. Verify `.grid` already falls into this branch (it does — only `.note` and `.card` are excluded, everything else including the new `.grid` routes to `pushFollowUp`). No code change needed here; just confirm by reading the method after Steps 1-2 land.

- [ ] **Step 4: Build to verify**

Run: `cd shell && swift build 2>&1 | tail -50`
Expected: builds clean, no exhaustive-switch warnings/errors remaining for `ShellViewState` or `UIPattern`.

- [ ] **Step 5: Run full shell test suite**

Run: `cd shell && swift test 2>&1 | tail -30`
Expected: all tests pass, including the new ones from Tasks 1-3.

- [ ] **Step 6: Commit**

```bash
git add shell/Sources/JugnuUI/ShellHost.swift
git commit -m "feat: dispatch grid pattern to GridPanelView in ShellHost"
```

---

## Task 6: `jugnu.audio-toggles` addon — manifest + bash scripts

**Files:**
- Create: `addons/jugnu.audio-toggles/addon.yaml`
- Create: `addons/jugnu.audio-toggles/bin/run`
- Create: `addons/jugnu.audio-toggles/bin/mute-mic`
- Create: `addons/jugnu.audio-toggles/bin/mute-all`
- Create: `addons/jugnu.audio-toggles/bin/audio-toggles-status`
- Create: `addons/jugnu.audio-toggles/README.md`
- Reference (read-only, do not modify): `addons/jugnu.mic-mute/bin/run`, `addons/jugnu.mute-all/bin/run`

**Interfaces:**
- Produces: a working addon directory validated by `scripts/validate-addon.sh`, emitting `{"ok":true,"ui":{"pattern":"grid",...}}` for `audio-toggles` and toast-shaped `{"ok":true,"message":"..."}` for `mute-mic`/`mute-all`.

- [ ] **Step 1: Create the manifest**

`addons/jugnu.audio-toggles/addon.yaml`:

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

- [ ] **Step 2: Create `bin/run` (thin router)**

```bash
#!/bin/bash
set -euo pipefail
request=$(cat)
root="$(cd "$(dirname "$0")" && pwd)"
command=$(printf '%s' "$request" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*:"([^"]*)"/\1/')

case "$command" in
  audio-toggles) printf '%s' "$request" | exec "$root/audio-toggles-status" ;;
  mute-mic)      printf '%s' "$request" | exec "$root/mute-mic" ;;
  mute-all)      printf '%s' "$request" | exec "$root/mute-all" ;;
  *) echo '{"ok":false,"error":"Unknown command"}'; exit 0 ;;
esac
```

- [ ] **Step 3: Create `bin/mute-mic` (copy of today's `jugnu.mic-mute/bin/run` body, unchanged)**

```bash
#!/bin/bash
set -euo pipefail
cat >/dev/null

state=$(osascript <<'APPLESCRIPT'
set vol to input volume of (get volume settings)
if vol is 0 then
  set volume input volume 75
  return "unmuted"
else
  set volume input volume 0
  return "muted"
end if
APPLESCRIPT
)

if [[ "$state" == "muted" ]]; then
  echo '{"ok":true,"message":"Microphone muted"}'
else
  echo '{"ok":true,"message":"Microphone unmuted"}'
fi
```

- [ ] **Step 4: Create `bin/mute-all` (copy of today's `jugnu.mute-all/bin/run` body, state dir changed)**

```bash
#!/bin/bash
set -euo pipefail
cat >/dev/null

state_dir="${JUGNU_STATE_DIR:-$HOME/.local/share/jugnu/state/audio-toggles}"
state_file="$state_dir/volumes"

is_volume() {
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 0 && 10#$1 <= 100))
}

osa="${OSASCRIPT:-osascript}"

if [[ -f "$state_file" ]]; then
  output=$(sed -n '1p' "$state_file")
  input=$(sed -n '2p' "$state_file")
  if ! is_volume "$output" || ! is_volume "$input"; then
    echo '{"ok":false,"error":"Saved mute-all volumes are invalid"}'
    exit 0
  fi
  if ! "$osa" -e "set volume output volume ${output}" -e "set volume input volume ${input}"; then
    echo '{"ok":false,"error":"Could not restore volume"}'
    exit 0
  fi
  rm -f "$state_file"
  echo '{"ok":true,"message":"Volumes restored"}'
  exit 0
fi

vols=$("$osa" -e 'output volume of (get volume settings)' -e 'input volume of (get volume settings)') || {
  echo '{"ok":false,"error":"Could not read volume"}'
  exit 0
}
output=$(printf '%s\n' "$vols" | sed -n '1p' | tr -d '[:space:]')
input=$(printf '%s\n' "$vols" | sed -n '2p' | tr -d '[:space:]')
if ! is_volume "$output" || ! is_volume "$input"; then
  echo '{"ok":false,"error":"Could not read volume"}'
  exit 0
fi

mkdir -p "$state_dir"
printf '%s\n%s\n' "$output" "$input" >"$state_file"

if ! "$osa" -e 'set volume output volume 0' -e 'set volume input volume 0'; then
  echo '{"ok":false,"error":"Could not mute"}'
  exit 0
fi

echo '{"ok":true,"message":"Microphone and speakers muted"}'
```

- [ ] **Step 5: Create `bin/audio-toggles-status` (new — reads live state, emits grid JSON)**

Mic-active means muted (input volume 0). Mute-all-active means the state file exists (same "is there a saved-volumes marker" signal `bin/mute-all` itself uses to decide restore-vs-mute):

```bash
#!/bin/bash
set -euo pipefail
cat >/dev/null

state_dir="${JUGNU_STATE_DIR:-$HOME/.local/share/jugnu/state/audio-toggles}"
state_file="$state_dir/volumes"
osa="${OSASCRIPT:-osascript}"

mic_vol=$("$osa" -e 'input volume of (get volume settings)' 2>/dev/null) || {
  echo '{"ok":false,"error":"Could not read microphone state"}'
  exit 0
}
mic_vol=$(printf '%s' "$mic_vol" | tr -d '[:space:]')

mic_active=false
[[ "$mic_vol" == "0" ]] && mic_active=true

all_active=false
[[ -f "$state_file" ]] && all_active=true

cat <<JSON
{"ok":true,"ui":{"pattern":"grid","title":"Audio","gridItems":[
{"id":"mic","title":"Microphone","icon":"mic.fill","active":${mic_active},"actions":["mute-mic"]},
{"id":"all","title":"Mute All","icon":"speaker.slash.fill","active":${all_active},"actions":["mute-all"]}
]}}
JSON
```

- [ ] **Step 6: Make scripts executable**

Run:
```bash
chmod +x addons/jugnu.audio-toggles/bin/run addons/jugnu.audio-toggles/bin/mute-mic addons/jugnu.audio-toggles/bin/mute-all addons/jugnu.audio-toggles/bin/audio-toggles-status
```

- [ ] **Step 7: Create README.md**

Base it on the combined intent of the two old READMEs — read them first for tone:
```bash
cat addons/jugnu.mic-mute/README.md addons/jugnu.mute-all/README.md
```
Then write `addons/jugnu.audio-toggles/README.md` describing all three commands (`audio-toggles`, `mute-mic`, `mute-all`) in that same style.

- [ ] **Step 8: Validate the manifest**

Run: `scripts/validate-addon.sh addons/jugnu.audio-toggles`
Expected: `valid addon: jugnu.audio-toggles 1.0.0 (api 1)`

- [ ] **Step 9: Manual smoke test of the router**

Run:
```bash
echo '{"api":1,"op":"run","command":"audio-toggles","args":{}}' | addons/jugnu.audio-toggles/bin/run
echo '{"api":1,"op":"run","command":"mute-mic","args":{}}' | addons/jugnu.audio-toggles/bin/run
echo '{"api":1,"op":"run","command":"mute-all","args":{}}' | addons/jugnu.audio-toggles/bin/run
```
Expected: first prints grid JSON with two `gridItems`; second toggles mic mute and prints a toast message; third mutes/restores and prints a toast message. (This actually changes your live mic/speaker volume — run somewhere that's fine to test audio state changes, and re-run `mute-all` a second time to restore.)

- [ ] **Step 10: Commit**

```bash
git add addons/jugnu.audio-toggles
git commit -m "feat: add jugnu.audio-toggles addon (merges mic-mute + mute-all)"
```

---

## Task 7: Addon-level pytest coverage + delete old addons

**Files:**
- Create: `addons/jugnu.audio-toggles/tests/test_audio_toggles.py`
- Delete: `addons/jugnu.mic-mute/` (entire directory)
- Delete: `addons/jugnu.mute-all/` (entire directory)

**Interfaces:**
- Consumes: `addons/jugnu.audio-toggles/bin/run` and subscripts (Task 6).

- [ ] **Step 1: Write the test file**

Adapt `addons/jugnu.mute-all/tests/test_mute_all.py`'s fixture style (stub `osascript` binary via PATH override) to the merged addon, covering all three commands plus the router itself. Create `addons/jugnu.audio-toggles/tests/test_audio_toggles.py`:

```python
from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]
RUN = ADDON / "bin" / "run"


def _write_exec(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


def _env(tmp_path: Path, osascript_body: str) -> dict[str, str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    _write_exec(bin_dir / "osascript", osascript_body)
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["OSASCRIPT"] = str(bin_dir / "osascript")
    env["HOME"] = str(tmp_path / "home")
    env["JUGNU_STATE_DIR"] = str(tmp_path / "state")
    (tmp_path / "home").mkdir(exist_ok=True)
    return env


def _run(command: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    payload = json.dumps({"api": 1, "op": "run", "command": command, "args": {}})
    return subprocess.run(
        [str(RUN)], input=payload, capture_output=True, text=True, env=env, check=False
    )


def test_router_rejects_unknown_command(tmp_path: Path) -> None:
    env = _env(tmp_path, "#!/bin/bash\nexit 0\n")
    proc = _run("bogus", env)
    assert proc.returncode == 0
    payload = json.loads(proc.stdout)
    assert payload["ok"] is False


def test_mute_mic_toggles(tmp_path: Path) -> None:
    osa_body = """#!/bin/bash
cat <<'APPLESCRIPT_OUT'
muted
APPLESCRIPT_OUT
"""
    env = _env(tmp_path, osa_body)
    proc = _run("mute-mic", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert "mute" in payload["message"].lower()


def test_mute_all_mutes_and_saves(tmp_path: Path) -> None:
    set_log = tmp_path / "set.log"
    vol_file = tmp_path / "live-volumes"
    vol_file.write_text("40\n80\n", encoding="utf-8")
    osa_body = f"""#!/bin/bash
args="$*"
if [[ "$args" == *output\\ volume\\ of* ]] || [[ "$args" == *get\\ volume\\ settings* ]]; then
  cat "{vol_file}"
  exit 0
fi
printf '%s\\n' "$args" >> "{set_log}"
exit 0
"""
    env = _env(tmp_path, osa_body)
    proc = _run("mute-all", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    state = (tmp_path / "state" / "volumes").read_text(encoding="utf-8")
    assert state.splitlines()[:2] == ["40", "80"]


def test_audio_toggles_status_reflects_live_state(tmp_path: Path) -> None:
    osa_body = """#!/bin/bash
echo 0
"""
    env = _env(tmp_path, osa_body)
    proc = _run("audio-toggles", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["ui"]["pattern"] == "grid"
    items = {item["id"]: item for item in payload["ui"]["gridItems"]}
    assert items["mic"]["active"] is True
    assert items["all"]["active"] is False


def test_audio_toggles_status_reflects_mute_all_active(tmp_path: Path) -> None:
    state_dir = tmp_path / "state"
    state_dir.mkdir()
    (state_dir / "volumes").write_text("40\n80\n", encoding="utf-8")
    osa_body = """#!/bin/bash
echo 75
"""
    env = _env(tmp_path, osa_body)
    proc = _run("audio-toggles", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    items = {item["id"]: item for item in payload["ui"]["gridItems"]}
    assert items["mic"]["active"] is False
    assert items["all"]["active"] is True
```

- [ ] **Step 2: Run the tests to verify they pass**

Run (using the repo's `.venv` per project convention):
```bash
source .venv/bin/activate 2>/dev/null || true
python3 -m pytest addons/jugnu.audio-toggles/tests/test_audio_toggles.py -v
```
Expected: all 5 tests pass.

- [ ] **Step 3: Delete the old addons**

```bash
git rm -r addons/jugnu.mic-mute addons/jugnu.mute-all
```

- [ ] **Step 4: Search for stray references to the deleted addon ids**

```bash
grep -rln "jugnu.mic-mute\|jugnu\.mute-all" --exclude-dir=.git --exclude-dir=.build . 
```
Expected: only doc/backlog/ticket mentions (historical, fine to leave) and the registry file — check the registry build script/output next (Task 8 handles the registry).

- [ ] **Step 5: Commit**

```bash
git add addons/jugnu.audio-toggles/tests
git commit -m "test: add pytest coverage for jugnu.audio-toggles; remove mic-mute and mute-all"
```

---

## Task 8: Registry + docs cleanup

**Files:**
- Modify: whatever registry file/script `build-registry.sh` produces (find it first — likely `registry/registry.json` or similar; grep before editing)
- Modify: `docs/architecture/2026-08-24-view-types.md` §7 (update the `mic-mute`/`mute-all` TBD rows)
- Modify: `docs/tickets.md` (ticket 0074 row — mark implementation landed)

**Interfaces:**
- Consumes: the finished `jugnu.audio-toggles` addon (Tasks 6-7).

- [ ] **Step 1: Find and regenerate the registry**

```bash
find . -iname "build-registry.sh" -not -path "*/.build/*"
```
Run whatever that script is (read it first to confirm invocation) so it drops `jugnu.mic-mute`/`jugnu.mute-all` and picks up `jugnu.audio-toggles`. Confirm the output no longer references the old ids:
```bash
grep -l "jugnu.mic-mute\|jugnu.mute-all" registry/*.json 2>/dev/null
```
Expected: no matches.

- [ ] **Step 2: Update view-types doc**

In `docs/architecture/2026-08-24-view-types.md` §7's table, replace the `mic-mute` / `mute-all` TBD rows with a single row:

```
| `audio-toggles` | `grid` | Merged mic-mute + mute-all per 0074; live-status tap-to-toggle tiles — first real `grid` consumer, supersedes the earlier toast-only guess |
```

Remove the two old rows (`mic-mute` TBD, `mute-all` TBD).

- [ ] **Step 3: Update ticket 0074**

In `docs/tickets.md`, find the `| 0074 |` row and append to its last notes cell (do not remove existing history): `**2026-09-12 (impl):** Audio merge implemented — jugnu.audio-toggles ships with grid view (first real grid consumer); jugnu.mic-mute/jugnu.mute-all deleted. Clip-tools and Intervals merges remain unbuilt.`

- [ ] **Step 4: Run the full test suite one more time**

```bash
cd shell && swift test 2>&1 | tail -20
python3 -m pytest addons/jugnu.audio-toggles/tests/ -v
scripts/validate-addon.sh addons/jugnu.audio-toggles
```
Expected: everything green.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: land audio-toggles grid merge in view-types and ticket 0074"
```

---

## Task 9: Manual shell smoke test

**Files:** none (manual verification only)

- [ ] **Step 1: Build and run the app**

```bash
make run
```

- [ ] **Step 2: Walk the new addon in the live palette**

Open the palette (Opt+Space), search "Audio", invoke `audio-toggles` — confirm a grid panel opens with two tiles (mic, mute all), correct active/inactive visual state matching your Mac's actual current mic/speaker mute status. Tap the mic tile — confirm it toggles, panel re-renders with updated state. Tap mute-all tile — confirm it mutes both, re-invoke to confirm it restores. Invoke `mute-mic` and `mute-all` directly from the launcher (not through the grid) — confirm both still work standalone and that a subsequent `audio-toggles` open reflects whichever state they left the system in.

- [ ] **Step 3: Report results**

No code changes in this task — just confirm pass/fail of the walk above and note anything surprising (e.g. icon rendering, tile sizing at different screen widths) for a follow-up fix if needed.
