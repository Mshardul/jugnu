# Jugnu app shell product plan — Home, Catalog, Search, and Preferences

**Date:** 2026-10-12  
**Status:** Approved product plan — implementation not started  
**Scope:** The Jugnu app shell: shared frame, Home, Search, Catalog, Addon detail, and Preferences.  
**Terminology dependency:** [Ticket 0078](../tickets.md) finalizes public labels without changing the product model in this plan.

## 0. Scope and authority

Invoking Jugnu opens a glanceable, near-full-screen app with a modular Home.
Home, Catalog, and Preferences share one stable frame. This document is the
canonical product plan for those surfaces and is complete enough to drive an
implementation plan.

Jugnu has one view: this stable frame (§11.1). Running an action from Home,
Search, Catalog, or Addon detail keeps the frame. The panel does not change
size. An action that still presents a view-type panel keeps that presentation
until it is hosted in the frame; the shell does not grow a second geometry for
it. Per-Addon Settings live in the Addon's Settings section (§5.3); the editors
keep their current behavior. First run, the menu bar, and context are specified
in §11 and are not steps in §9.

Where this plan conflicts with the older shell, launcher, Catalog, detail, or
Preferences geometry and navigation documents listed in §13, this plan wins.
Protocol compatibility, packaging, security, lifecycle, cleanup, and latency
rules remain unchanged unless this document says otherwise.

## 1. Product direction

Jugnu should feel like a glanceable personal command workspace, not only a
search strip. Search remains immediate, but it is one interaction inside a
larger Home rather than the entire empty state.

The visual hierarchy is:

1. A stable app-level frame and navigation.
2. A user-arranged Home of compact, useful modules.
3. Global search available from anywhere on Home.
4. Full-frame Catalog and Preferences pages.
5. A focused action as a content block in that same frame (§11.1).

## 2. Shared app frame

Home, Catalog, and Preferences use one near-full-screen frame:

- Centered on the pointer screen when invoked and on the panel's current screen
  while visible.
- Sized from that screen's `visibleFrame` minus a 32 pt safe margin on every
  side.
- Not manually resizable. Users resize Home modules, not the app frame.
- Recalculated once after a cross-display move ends, not continuously while the
  window is being dragged.
- Home, Catalog, and Preferences swap page content without resizing the frame.
- Navigation state and page state survive page changes where expected.

Primary destinations use text labels because they must be unambiguous:
**Home**, **Catalog**, and **Preferences**. Compact universal actions use the
approved Jugnu icon system: Search, Add, Edit, Settings, Close, and similar
well-understood actions. Icon-only controls require a tooltip, hover/focus
state, and VoiceOver label.

Keyboard shortcuts may appear as subtle hints, but a shortcut such as `⌘K`
must not be styled as the control's label.

### 2.1 Invocation and dismissal

The configured invoke hotkey, Escape, click-outside, and Cmd+W have one
authoritative contract:

| Current state | Invoke hotkey | Escape | Click outside Jugnu | Cmd+W |
|---|---|---|---|---|
| Hidden | Open a fresh Home | No-op | No-op | No-op |
| Home | Hide and clear the route stack | Hide and clear the route stack | Ignore | Hide and clear the route stack |
| Search | Close Search and restore Home exactly | Close Search and restore Home exactly | Ignore the outer safe margin | Close Search and restore Home exactly |
| Edit Home | Exit Edit Home; keep committed edits | Exit Edit Home; keep committed edits | Ignore | Exit Edit Home; keep committed edits |
| Catalog | Go to Home | Pop detail when present; otherwise go to Home | Ignore | Pop detail when present; otherwise go to Home |
| Preferences | Go to Home | Go to Home | Ignore | Go to Home |
| Focused Addon UI | Go to Home | Pop and restore its originating page | Follow that view's existing command-level dismiss policy | Pop and restore its originating page |

Clicking Search's dimmed in-window backdrop closes Search and restores Home
exactly; it is not a click outside Jugnu. Leaving focused Addon UI continues to
apply its existing process-cancellation rules.

## 3. Home

### 3.1 Grid model

Home is a modular, auto-packing grid similar in interaction to macOS desktop
widgets:

- The available frame is divided into logical unit cells.
- Column and row availability is calculated from current geometry.
- Placed modules occupy whole-cell spans only.
- Moving and resizing snap to cells; free-form pixel placement is not allowed.
- Gaps are removed by deterministic automatic packing.
- Every module declares minimum and maximum column and row spans.
- Every whole-cell size inside those constraints is valid; there are no
  Small/Medium/Large-only size presets.

There is one system-wide layout, not a separate layout per display. The stored
model consists of stable module order, preferred normalized width, preferred
logical height, and instance configuration:

- Width is a rational fraction of a canonical logical grid, not a floating
  percentage and not a pixel value.
- The fraction maps to the available columns and then snaps to a whole span.
- Height is stored in logical row units.
- Module min/max constraints are applied after mapping.
- Returning to a wider screen restores the preferred proportion rather than
  permanently overwriting it with the temporary narrow-screen clamp.

This preserves one recognizable layout across a MacBook and an external
monitor while allowing each screen to use its available columns.

Grid calculation and packing are deterministic:

- `frameSafeMargin`, `unitMinWidth`, `unitRowHeight`, `gap`, and `maxColumns`
  are shell-owned layout tokens. Initial reference values are 32 pt, 160 pt, a
  96 pt minimum row height, 12 pt, and 12 columns; final reference mockups may
  tune these tokens without changing the model. Dynamic Type may increase the
  effective row height from that minimum; required controls never truncate to
  preserve 96 pt.
- Column count is
  `min(maxColumns, max(1, floor((contentWidth + gap) / (unitMinWidth + gap))))`.
  Cells divide the remaining width equally.
- Row count is not stored. Rows continue vertically and Home scrolls when the
  packed layout exceeds the visible height.
- Preferred width is stored as an exact rational value. Runtime span is
  `roundHalfUp(preferredWidth × columnCount)`, clamped to the definition's
  min/max and then to available columns.
- Preferred height is an integer row span clamped to the definition's min/max.
- If the screen has fewer columns than a widget's declared minimum, that widget
  temporarily spans every available column and must render its compact
  structure. Validation rejects definitions whose minimum cannot render in the
  shell's one-column fallback.
- Packing walks instances in stable user order and places each rectangle in the
  first available top-left position. It fills earlier viable holes but does not
  distort widget spans to eliminate geometrically unavoidable holes.
- A drag changes stable order; it does not store an origin cell. Dropping over
  an occupied cell inserts before the first instance occupying that cell.
  Dropping over an empty cell inserts after the last packed instance preceding
  that cell in row-major order. The preview shows the resulting first-fit
  placement before release.
- Resizing keeps the instance's order. Later instances re-pack. Temporary
  clamps never overwrite stored preferred dimensions.
- At the end of a resize, preferred width is written as
  `finalSpan / columnCount` reduced to lowest terms; preferred height is the
  final row span. Intermediate pointer movement updates memory only.
- Keyboard and VoiceOver move through placed widgets in visual row-major order
  after packing.

For example, if A and B fill the first row and C begins the second, dropping D
over B produces order A, D, B, C and then first-fit packs that order. Dropping D
in empty space after C produces A, B, C, D. A later display change may move
their cells, but their order remains recognizable.

### 3.2 Responsive module content

Module content adapts to its allocated span:

- Increasing height reveals more list entries.
- Decreasing height removes lower-priority entries before core controls.
- Increasing width permits longer lines and additional columns.
- Decreasing width wraps text naturally and reduces column count.
- Lists, text, and grids use shell-owned responsive behavior.
- An Addon supplies one declarative responsive layout, not one layout for every
  possible cell span.
- Optional compact, regular, and wide variants are allowed only when the
  structure genuinely changes.

### 3.3 Normal mode and Edit Home

Normal Home is for using modules. Moving, resizing, adding, removing,
duplicating, and configuring modules happen only in explicit **Edit Home**
mode, preventing accidental layout changes.

Edit Home exposes:

- Drag handles and cell-snapped resize affordances.
- Remove and duplicate actions.
- Add Widget library.
- Per-instance configuration.
- Done/exit control that returns to normal interaction.

Clicking a library item adds it at the next automatically packed position using
its default size. Dragging a library item chooses an insertion point in stable
order and previews the resulting packed location. Required configuration
follows placement; optional configuration uses defaults.

Edit Home is immediate and atomic, not a Save/Cancel transaction:

- Every valid move, resize, removal, duplication, reorder, and configuration
  change updates the in-memory layout. A drag or resize persists one complete
  layout snapshot atomically when the gesture ends, not on every pointer tick;
  discrete actions persist once when accepted.
- **Done** exits Edit Home; it does not commit a separate draft.
- A widget requiring initial configuration is a pending placement and is not
  persisted until its required fields are valid.
- Dismissing or crashing during required configuration discards only that
  pending placement. Earlier valid edits remain committed.
- Relaunch loads the last complete snapshot; a partial write cannot replace it.

### 3.4 Built-in and Addon-provided modules

This plan uses **Widget** as its implementation term. Ticket 0078 may refine
the public label and related vocabulary before UI copy is frozen.

Jugnu supplies Favorite Addons, Recent Activity, Updates, and Running Work
built-in widgets. A new Home starts with Favorite Addons and Recent Activity at
one-half preferred width and three rows each, followed by Updates at one-half
preferred width and two rows. Each has a useful empty state; Addon widgets are
never placed automatically. Running Work is available from the library but is
not placed by default.

Running Work shows only work already allowed to outlive a page: shell-owned
install/update operations, scheduler-owned widget refresh, and daemon state the
user has already turned on. It does not make a focused Addon job survive
navigation or amend the existing job lifecycle.

Installed Addons may contribute their own widgets. An Addon may provide
multiple widget definitions, and a user may place multiple independently
configured instances of one definition.

Live status is compact content inside a widget, not a set of oversized
dashboard buttons. Interactive controls receive only the space their action
requires; resizing a widget primarily changes information density and visible
entries.

The shell owns:

- Widget frame, title, visual tokens, focus, accessibility, and error chrome.
- Grid placement, resizing, and edit-mode behavior.
- The catalog of allowed layout and interaction primitives.
- Loading, disabled, stale, empty, and failure states.
- Refresh scheduling and resource budgets.
- Instance identity and persisted placement.

The Addon owns:

- Integration and job logic.
- Widget data and typed instance configuration.
- Mapping shell-rendered interactions to Addon behavior.
- Returning the next widget snapshot after an interaction or refresh.

Widgets are declarative. Addons do not embed arbitrary SwiftUI, AppKit, HTML,
or JavaScript in Home. Version 1 is closed to these shell-owned primitives:

- Layout: horizontal stack, vertical stack, adaptive grid, spacer, and divider.
- Content: text, packaged icon/image, value, list, and progress.
- Interaction: button, toggle, radio group, menu, and list reorder.

Version 1 has no arbitrary text input, embedded document, script, or custom
renderer. New primitives require an additive protocol version and a real
product need. An unknown primitive fails closed with the bounded shell-owned
unsupported state.

Built-in and Addon widgets render through this same primitive set.

A widget definition may mark a value as a shell-owned clock. The shell then
updates displayed elapsed, remaining, or civil time locally between snapshots.

An interaction sends the widget instance id, action id, and typed value to the
Addon. The Addon performs the work and returns updated widget state. When the
next state of a button or toggle is known, the shell shows it immediately and
reconciles with that snapshot, reverting if the Addon fails. When the next
state is not known, the control shows a pending state and ignores further
activation until the snapshot returns. Complex flows open the action as a
content block in the frame (§11.1) rather than recreating the full flow inside
a widget.

### 3.5 Refresh and latency

Widget state uses a snapshot-first model:

- Cached state renders immediately when Home appears.
- Widgets refresh when Home opens.
- Widgets refresh after user interaction.
- Widgets may request scheduled/background refresh.
- Jugnu controls allowed intervals, concurrency, and resource budgets.
- Widget refresh never blocks Home's first paint.

A refresh failure keeps valid cached content visible with a stale/error
indicator. A widget with no usable snapshot shows a bounded shell-owned failure
state and retry action.

Refresh ownership is explicit:

- **Widget refresh** is a scheduler-owned invocation of the existing oneshot
  process model, not a new Addon manifest lifecycle. Its owner is the app
  scheduler rather than a view, so it is exempt only from panel-leave
  cancellation.
- The app-level scheduler owns requested background refresh; Home does not.
- Leaving Home cancels only Home-open and interaction refresh tasks. Scheduled
  refresh the scheduler has accepted remains active while Jugnu is running.
- A widget definition may request scheduled refresh by declaring a preferred
  maximum snapshot age. The scheduler accepts that request and clamps it:
  visible refresh at most once per 30 seconds per instance, background refresh
  at most once per 15 minutes per Addon, and at most one background refresh
  process at a time.
- Every due instance of one Addon is refreshed by that one process. The
  response contains every due instance.
- A value marked as a shell-owned clock updates displayed elapsed, remaining,
  or civil time locally between snapshots, without launching the Addon to tick.
- Sleep suspends scheduling. Wake re-evaluates due snapshots without replaying
  every missed interval.
- Disable, uninstall, or app quit cancels scheduled work for the affected
  Addon.
- Refresh runs under the Addon's existing declared permissions and process
  restrictions. One coalesced response is capped at 256 KiB of uncompressed
  JSON; packaged assets are referenced, not embedded in the response.

### 3.6 Widget library

The widget library is a right-side panel shown only in Edit Home. The Home grid
remains visible so a widget can be dragged directly into place.

Library structure:

- Only installed Addons that provide widgets appear.
- Jugnu's built-in widgets are grouped in a Jugnu section.
- Each Addon gets a section with icon, name, and widget count.
- Several widget preview cards are visible inline in each section.
- A section scrolls horizontally only when its cards overflow.
- Partial next-card visibility and explicit arrows indicate overflow.
- The library scrolls vertically through Addon sections.
- Search matches installed Addon names and widget names, hiding empty sections.

Selecting a placed widget while in Edit Home changes the same side panel from
the library to that instance's inspector. For example, selecting a World Clock
widget may reveal City, Time Format, Show Date, and Remove Widget. A Back
control returns to the library. Configuration previews live and persist
automatically.

### 3.7 Install, disable, and uninstall

Installing an Addon never changes Home automatically. If the Addon provides
widgets, install completion may offer **Add Widget to Home** as an optional
follow-up; the widgets also become available in the library.

Disabling and uninstalling differ:

- Disabled Addon widgets stay in place and show an inactive state with an
  Enable action.
- Uninstall confirmation discloses how many Home widgets will be removed.
- Confirmed uninstall removes those instances and their configuration, then
  auto-packs the remaining layout.
- Reinstall does not silently restore removed widgets.

### 3.8 Favorite Addons

Favorites apply to Addons, not to individual actions. There is one shared
Favorite Addons list:

- Favoriting a Catalog card adds the Addon.
- The built-in Favorites Home widget displays that list.
- Reordering rows in the Home widget uses the list-reorder primitive and
  changes the shared order.
- There is no separate pinning model.

Migration resolves each existing `favoriteCommandIDs` entry to its owning
Addon, preserves first-occurrence order, deduplicates repeated Addons, and
drops unresolved ids. The old `palette.first_view` key remains parseable for
configuration compatibility but has no effect once Home ships; its Preferences
row is removed. Existing recent-action history remains internal data for
Recent Activity.

## 4. Global search

Search opens as an in-window modal over Home:

- The complete widget grid remains visible, dimmed, and non-interactive.
- The grid does not resize, reflow, or lose state while search is open.
- Search receives keyboard focus and presents scrollable results.
- Escape closes search and restores Home exactly.
- Clicking the Search icon or field opens it explicitly.
- Typing an unmodified printable character while Home has neutral focus opens
  it and carries the character into the query. Type-to-search does not intercept
  input when a text editor, menu, control, drag operation, or other first
  responder is consuming the event.

The modal is part of the single Jugnu window, not a second `NSWindow`.

Users do not need to understand “Commands” as product jargon. Search may show a
specific executable item as `Addon › Action`, because multi-action Addons such
as Audio and Clip Tools still need deterministic, directly searchable
behavior. Internal manifest and protocol compatibility is unchanged by this UI
wording.

Version 1 searches installed Addons, their executable Actions, app
destinations, and settings rows that actually exist. Uninstalled Addons remain
Catalog-search results, not global-search results. Arbitrary widget content and
focused widget fields are not part of the corpus. One Escape closes only the
Search layer.

## 5. Catalog

### 5.1 Guided Explorer

Catalog uses a **Guided Explorer** layout:

- Persistent left navigation.
- A restrained discovery feature rather than a storefront full of promotions.
- Search and filter controls.
- A scalable Addon card grid.
- Enough editorial guidance for discovery without sacrificing management of
  hundreds of Addons.

The sidebar is one exclusive navigation axis.

**Browse**

- Discover — default
- All Addons
- Installed
- Updates
- Recent
- Favorites

**Categories**

- Expandable categories and subcategories from the catalog taxonomy.

Search and filter chips narrow the current sidebar selection; they do not
silently reset it. Updates shows a count only when action is required.

Discover is deterministic editorial content from the registry: Addons tagged
`recommended`, in registry order, followed by category entry points. It uses
the last valid cached registry when offline and falls back to All Addons if no
recommended entries exist. It does not personalize or infer recommendations.
Favorites and Recent are the personal surfaces.

### 5.2 Cards

A scalable Catalog card contains:

- Addon icon and name.
- Short description.
- Trust badge.
- Widget count when relevant.
- Favorite Addon action.
- At most one state-aware primary action.

Primary action precedence is:

1. An absent Addon shows **Install**.
2. An installed Addon with an available update shows **Update**, regardless of
   enabled state.
3. An installed disabled Addon shows **Enable**.
4. An installed enabled Addon with a valid primary Action shows **Open**.
5. An installed enabled Addon without a primary Action has no primary button;
   selecting its card still opens detail.

Selecting the card opens details. Disable and Uninstall are intentionally kept
off the dense grid and live on the detail page.

### 5.3 Addon detail

Addon detail uses the same frame as Catalog and Preferences: the top bar, one
left pane, and one content pane.

While an Addon is open, the left pane lists that Addon's sections:

- **Overview** — description, screenshots, version, trust, and requirements.
- **Actions** — searchable executable actions, with Run where available.
- **Widgets** — widget previews, supported behavior, and Add to Home.
- **Settings** — that Addon's configuration and permissions when it is
  installed.

The content pane shows the selected section. Its header keeps the Addon name,
icon, and primary action. Back, at the top of the left pane, restores the
Catalog rail and the exact prior Catalog scope, category, filters, selection,
and scroll position. Choosing Catalog in the top bar does the same.

Uninstalled Addons can preview their widgets but must be installed before a
widget is placed.

Settings are edited only in this Settings section. Preferences → Installed and
Preferences search open that same section. Preferences does not host a second
copy of the controls.

## 6. Preferences

Preferences uses a persistent sidebar and one focused settings pane.

**Personal**

- Appearance — current theme presets, preview, and light/dark editors.

**Addons**

- Installed — directory of installed Addons. Each row opens that Addon's
  Settings section.
- Updates — Jugnu version, keep-current toggles, Check for Updates, and registry
  URL.

**System**

- General — sound. Menu-bar pins and context toggles (§11.3, §11.4) are
  further rows here and ship with those behaviors.

Preferences search covers shell settings and settings exposed by installed
Addons. Settings use consistent labeled rows and shell-owned controls.
Permission and update badges appear only when attention is required. Changes
save immediately unless the action is destructive or requires explicit
confirmation.

Install, Enable, Disable, and Uninstall remain Catalog responsibilities rather
than being duplicated throughout Preferences.

Per-Addon settings are the Addon's Settings section in §5.3. Preferences
search jumps to a matching row in that section and does not duplicate the
controls.

Hotkeys, Permissions, Privacy, and About are omitted until their designs provide
real rows; no empty or disabled destinations ship. The old empty-search
first-view control is removed because invocation now always opens Home.

## 7. Navigation and state restoration

The app-level routes are:

```text
Home
├── Search modal
├── Edit Home
│   ├── Widget library
│   └── Widget instance inspector
Catalog
├── Guided Explorer
└── Addon detail
    ├── Overview
    ├── Actions
    ├── Widgets
    └── Settings
Preferences
├── Appearance
├── Addons
│   ├── Installed
│   └── Updates
└── General
```

Page navigation preserves meaningful state. Returning from Addon detail
restores Catalog state. Closing Search restores Home state. Leaving Edit Home
keeps the committed layout. Existing pop, dismiss, cancellation, and state
restoration machinery should be reused where it expresses these routes; this
plan's route tree and outcomes are authoritative when old destination geometry
or labels conflict.

## 8. Implementation requirements

### 8.1 Data model

The implementation needs durable, typed models for:

- One ordered Home layout shared across displays.
- Widget definitions from Jugnu and installed Addons.
- Widget instances with stable ids, definition ids, normalized preferred width,
  preferred row span, order, and typed configuration.
- Definition-level default/minimum/maximum spans.
- Cached widget snapshots with freshness and failure metadata.
- Favorite Addon ids and their shared order.
- Catalog and Preferences navigation snapshots.
- An integer schema version on the Home layout snapshot. A snapshot newer than
  the running build understands is left untouched.
- Registry index fields for each widget: name, static preview, and count, taken
  from the Addon manifest, so Catalog cards and uninstalled Addon detail can
  show them before install.

Layout, instance configuration, and cached state have different lifetimes and
must not be collapsed into one untyped store. Additive migration must preserve
existing user configuration and favorites where a deterministic mapping
exists. Migration behavior for `favoriteCommandIDs` and `palette.first_view` is
fixed in §3.8.

### 8.2 Widget boundary

The widget contract is a versioned declarative boundary. It needs:

- Definition metadata and responsive shell primitives.
- Typed configuration schema.
- Snapshot request and response.
- Interaction request containing instance id, action id, and typed value.
- Optional refresh request within shell-controlled limits.
- Explicit unsupported-primitive, invalid-state, timeout, and disabled
  failures.
- A closed v1 primitive enum matching §3.4; decoding any other value fails
  closed.

Exact JSON field names belong in the implementation plan and protocol spec.
They must remain additive after release and must not reuse existing `api: 1`
keys with new meanings.

### 8.3 Performance and lifetime

- Hotkey to app-frame first paint keeps the existing 50 ms target and 100 ms
  ceiling.
- The validated Home layout, route model, action index, and latest usable widget
  snapshots are loaded into memory during app launch, before the first invoke.
  Key-down to first paint performs no filesystem or network work.
- Home paints frame, navigation, grid geometry, and cached widget snapshots
  before starting Addon refresh work.
- Widget refresh, Catalog network work, and Addon actions stay off MainActor.
- Leaving Home or dismissing Jugnu cancels Home-open and interaction refresh
  work. The app-level scheduler continues only scheduled refresh it has
  accepted (§3.5).
- Scheduled refresh is bounded, coalesced, sleep-aware, and cancelled on
  disable, uninstall, or quit.
- Search opens from the in-memory action index; it performs no filesystem walk,
  manifest decode, process spawn, or network request before results appear.

### 8.4 Accessibility and input

- The complete Home, Search, Catalog, detail, and Preferences flow is keyboard
  navigable. On Home, keyboard and VoiceOver order is visual row-major order
  after packing (§3.1).
- Grid movement and resize have keyboard alternatives in Edit Home.
- Icon-only controls have tooltips and accessibility labels.
- Dynamic type and VoiceOver do not hide required controls.
- Reduce Motion removes animated packing and other frame animation without
  changing state.
- Search preserves the user's first responder when dismissed.

### 8.5 Failure and empty states

Implementation and final mockups must cover:

- Empty Home and no installed Addon widgets.
- Empty Catalog scope/filter.
- Offline Catalog with cached results.
- Widget loading, stale cache, timeout, malformed response, and disabled Addon.
- Addon uninstall removing one or more placed widgets.
- Catalog install/update failure.
- Missing permissions and permission loss.
- Home layout migration or recovery failure.

Failures stay local to the affected widget or page unless the entire surface is
unusable. A failed widget must not block Home.

## 9. Delivery sequence

1. **Authority, vocabulary, and reference surfaces** — apply the §13
   supersession map; complete ticket 0078 before naming public protocol fields;
   finalize canonical Home, Search, Edit Home, widget library/inspector,
   Catalog/detail, and Preferences mockups before product UI code begins.
2. **Canonical models and migration** — frame route model, Home layout with
   schema version, favorites, widget definition/instance/snapshot types, and
   the registry widget index.
3. **Shared large frame** — Home/Catalog/Preferences navigation, geometry,
   state restoration, accessibility, and latency instrumentation. New routes
   use the single view (§11.1). Hosting each existing action in that frame
   proceeds action by action.
4. **Built-in Home** — grid, auto-packing, the default Favorites/Recent/Updates
   layout, optional Running Work, responsive sizing, and Edit Home. Built-in
   widgets render through the shared primitive set, including list reorder.
5. **Widget authoring contract** — declarative primitives, the shell-owned
   clock flag, instance configuration, interaction, cache, refresh, failures,
   validation, and one first-party Addon consumer. The manifest gains a
   `widgets` list beside commands and UI.
6. **Widget library and inspector** — installed-Addon sections, search,
   click/drag placement, per-instance configuration, duplicate/remove.
7. **Search modal** — type-to-search, dimmed Home, exact state restoration,
   `Addon › Action` result wording.
8. **Catalog** — Guided Explorer, card model, Favorite Addons, and Addon
   detail in the shared left-pane frame.
9. **Preferences** — full-frame persistent sidebar with only Appearance,
   Installed, Updates, and General. Installed opens Addon Settings in §5.3.
10. **Failure and quality completion** — all states in §8.5, Reduce Motion,
    keyboard, VoiceOver, localization, multi-display, and performance smoke.

Each phase must ship coherent behavior with tests; do not expose empty
destinations or unsupported widget primitives. First run, the menu bar, and
context are specified in §11 and are not steps in this sequence.

## 10. Rejected directions

These alternatives were considered and rejected for this plan:

### Home and frame

- A compact type-first launcher as the primary Home — it does not satisfy the
  glanceable workspace goal.
- A fixed editorial Home, command dock, or shell-only dashboard — it cannot
  adapt to each user's installed Addons and priorities.
- A free-form pixel grid, stored pixel/physical dimensions, or floating-point
  percentage positions — they make snapping and cross-display persistence
  unstable.
- Separate Home layouts per display — users should see one recognizable Home
  on a MacBook and monitor.
- User-preserved empty grid gaps instead of automatic packing — gaps fragment
  narrow layouts and make reflow unpredictable.
- Small/Medium/Large-only widget sizes instead of every valid cell span — the
  responsive contract already supports useful intermediate sizes.
- Always-visible layout controls instead of explicit Edit Home — normal use
  would be vulnerable to accidental movement and removal.
- A manually resizable app frame — it adds a second independent layout
  variable without improving the core workflow.
- Automatically adding widgets when an Addon installs — installation must not
  mutate a user's Home without consent.
- Restoring removed widget instances silently after reinstall — uninstall
  intentionally removes their configuration and layout presence.

### Widgets

- Shell-only widgets with no Addon contribution — Home must grow with the
  Addon ecosystem.
- Arbitrary embedded SwiftUI, AppKit, HTML, or JavaScript from Addons — it
  breaks shell consistency, trust boundaries, accessibility, and compatibility.
- Display-only widgets with no shell-defined interaction primitives — useful
  controls should complete small actions without opening full Addon UI.
- One instance per widget definition — clocks, timers, and similar jobs require
  independently configured instances.
- Refresh only on open/interaction with no bounded scheduled refresh — status
  widgets need controlled freshness while Jugnu is running.
- A separate hand-authored layout for every possible span — it does not scale
  to continuous cell-based resizing.
- A flat ungrouped widget library — users discover widgets by installed Addon,
  and a flat list loses that context.
- Showing widgets from uninstalled Addons — discovery belongs in Catalog; the
  Home library contains immediately usable items.
- Centered-gallery and bottom-tray pickers; the visible-grid side library is
  authoritative because users need to see placement while browsing.
- Opening another modal for instance configuration; the side inspector is
  authoritative because it preserves the grid and avoids stacked chrome.

### Search and navigation

- Replacing Home with a search-results page — it destroys glanceable context
  for a transient action.
- Compressing Home into a persistent split-search layout — it compromises both
  widgets and results.
- Resizing/reflowing Home while search is active — dismissal must restore the
  exact visual state without movement.
- A second search window — the app keeps one shell-owned focus target.
- Text or shortcut-glyph buttons such as a `⌘K` control — compact universal
  actions use meaningful icons; shortcuts are hints, not labels.
- Icon-only primary destination navigation — Home, Catalog, and Preferences
  need explicit labels.
- Different frame sizes for Home, Catalog, and Preferences — frame changes make
  the app feel like disconnected surfaces.

### Catalog and Preferences

- A purely utilitarian Catalog Explorer with no discovery guidance — Catalog
  must help users find unfamiliar Addons.
- A shelf-heavy storefront that hides catalog scale and management — it becomes
  inefficient with hundreds of Addons.
- Addon detail as a modal or narrow side inspector — Overview, Actions,
  Widgets, and Settings use the shared frame's left pane and content pane.
- Lifecycle controls duplicated on every Catalog card — dense cards need one
  primary action; destructive and secondary actions belong in detail.
- User-facing **Commands** terminology — users see an Addon and its Actions;
  internal manifest compatibility remains unchanged.
- Separate command favorites and Addon favorites — one Addon-level favorites
  model avoids overlapping concepts.
- Preferences as a category landing grid or one dense settings dashboard —
  both add friction as settings grow; the persistent sidebar keeps context.
- Duplicating install/enable/disable/uninstall controls in Preferences —
  Catalog remains the single lifecycle surface.

Do not revive a rejected direction without new evidence that invalidates the
reason it was rejected.

## 11. First run, menu bar, context, and the single view

The single view is part of the §9 delivery. First run, the menu bar, and
context are part of the product and are not steps in that sequence.

### 11.1 Single view

Jugnu has one view: the stable frame in §2. Running an action keeps that frame.
The panel does not change size. The action is a content block in the content
pane, compact when the action is short and larger when its content needs the
room. Closing the action returns to the section the user left. An instant
action is a toast. An action that still presents a view-type panel keeps that
presentation until it is hosted here. New routes do not resize the panel.

### 11.2 First run

The first screen is the default Home. A short introduction in that same frame
offers recommended Addons. Skip leaves Home unchanged.

### 11.3 Menu bar

Jugnu has one menu-bar item. With no pinned Addons the menu is:

```text
Open Jugnu
Open Preferences
────────────
Quit
```

The user can pin up to five installed Addons, in an order they choose. A fresh
install has none. Pinned rows sit between two dividers:

```text
Open Jugnu
Open Preferences
────────────
Temporary Folder
Floating Note
────────────
Quit
```

Choosing a row runs that Addon's menu-bar job. An Addon declares at most one,
by pointing at an existing command or detached pattern such as tray or note.
Temporary Folder drops its tray. Floating Note shows the note. Disabling or
uninstalling an Addon removes its row. The user orders the pins in
Preferences → General. That row ships with the menu bar.

### 11.4 Context

A matching action appears only when the user invokes Jugnu, inside the same
frame. It does not appear because the selection, clipboard, or frontmost app
changed. Those three signals are the sources. Each signal is off until the user
turns it on. Matching stays on this Mac. With a signal off, or its permission
denied, Search behaves as specified in §4. The three toggles live in
Preferences → General and ship with context.

### 11.5 Points of view

§11 covers these points of view:

- First-time and non-technical user.
- Keyboard-first power user.
- VoiceOver, keyboard-only, Dynamic Type, and Reduce Motion user.
- MacBook-only, external-monitor, multi-display, and display-change behavior.
- Offline, slow-network, stale-cache, and permission-denied behavior.
- User with no Addons, many Addons, many widget instances, and a full grid.
- First-party and third-party Addon author.
- Localized UI with long translations, locale-sensitive sorting/search, and
  right-to-left layout.
- Privacy, trust, sandboxing, resource use, and malicious/malformed Addon
  behavior.
- Upgrade and compatibility from existing Jugnu installs.

## 12. Acceptance criteria

The implementation is complete when:

1. Invoking Jugnu paints the fixed near-full-screen frame and cached Home within
   existing latency budgets.
2. One canonical Home layout reflows deterministically across screen sizes and
   restores preferred proportions when space returns.
3. Every widget span inside its definition's min/max bounds works; content
   responds as specified in §3.2.
4. Edit Home supports keyboard-accessible add, drag/place, resize, duplicate,
   configure, remove, automatic packing, and persistence.
5. Built-in and Addon widgets share shell chrome and the §3.4 primitives,
   including list reorder and shell-owned clock values. Multiple configured
   instances work independently. A button or toggle shows its known next state
   immediately, or a pending state when that next state is unknown.
6. Cached, refresh, scheduled, stale, disabled, error, uninstall, and migration
   states behave without blocking Home.
7. Search opens over an unchanged Home, supports type-to-search, presents
   `Addon › Action`, and restores focus/state on dismissal.
8. Home, Catalog, and Preferences swap inside one stable frame.
9. Catalog implements the Guided Explorer, Favorite Addons, state-aware cards,
   left-pane Addon detail, and exact browse-state restoration.
10. Preferences implements the persistent sidebar and agreed information
    architecture without duplicating Catalog lifecycle controls.
11. Disabling preserves inactive widgets; uninstall disclosure removes widget
    instances/configuration and auto-packs; reinstall does not restore them.
12. Automated tests cover pure layout/reflow/packing, persistence/migration,
    protocol validation, refresh/error behavior, search state, Catalog state,
    and lifecycle consequences.
13. Manual smoke covers keyboard, VoiceOver, Reduce Motion, offline behavior,
    permission failure, display changes, and latency on representative Macs.
14. Invoke hotkey, Escape, click-outside, and Cmd+W match the §2.1 matrix from
    every route.
15. A fresh install receives the default built-in Home layout, while Addon
    widgets remain opt-in.
16. Home keyboard and VoiceOver order follows visual row-major order after
    packing.
17. A Home layout snapshot newer than the running build is left untouched.
18. Catalog cards and uninstalled Addon detail show widget name, static
    preview, and count from the registry index.

## 13. Superseded constraints and unchanged foundations

This plan supersedes:

- Compact empty `seek` as the primary Home.
- Launcher-only favorites row as Home.
- Separate smaller Catalog and Preferences geometry.
- Smaller stacked Addon detail over Catalog.
- User-facing **Commands** tab wording.

This plan does not change:

- Category → Addon packaging. Widgets are a manifest list on the Addon,
  beside commands and UI, not a catalog level. Ticket 0078 chooses the public
  label.
- Out-of-process Addon execution.
- Shell ownership of windows, rendering, interaction primitives, and view
  geometry.
- Latency budgets and first-paint constraints.
- One main shell-owned `KeyablePanel` and its navigation stack.
- Permission, installer, lifecycle, privacy, trust, and cleanup requirements.
- View-type panels for an action until that action is hosted in the frame
  (§11.1). New routes do not use them.

The scheduler-owned widget-refresh exception is limited to §3.5. Existing
shell-owned detached chrome remains outside the main stack: toast HUD, status
surface, tray, note, card, and other already-defined detached patterns. The
menu bar itself is specified in §11.3. Tray, note, and the other detached
patterns keep their current behavior.

Supersession map:

- [Vision](../vision.md)
- [Shell surface presets](./2026-08-23-shell-surface-presets.md) — superseded
  for Home/Catalog/Preferences geometry and app-route invocation; still binding
  for the main-panel stack, focused Addon UI, detached chrome, process
  cancellation, and state restoration where §2.1 does not override it.
- [Launcher and Catalog design](./2026-08-25-launcher-catalog-design.md) —
  superseded for launcher/Home, favorites, Catalog presentation, and
  user-facing terminology; registry taxonomy and lifecycle behavior remain.
- [View types](./2026-08-24-view-types.md) — binding only for an action that is
  not yet hosted in the frame (§11.1). Home, Catalog, Preferences, Addon
  detail, and new routes use the shared frame.
- [Preferences canvas](./2026-09-10-prefs-canvas-design.md) — superseded for
  frame geometry, navigation, and the removed first-view row; existing setting
  behavior and storage remain.
- [Addon detail tabs](./2026-09-10-addon-detail-tabs-design.md) — superseded for
  geometry, tab labels, and app navigation; config passthrough and existing
  Settings behavior remain.
- [Visual mockup set](./2026-09-11-visual-design-mockups.md) — canonical
  app-shell references are [Home/Search/Edit Home](../mockups/shell/home.html),
  [Catalog/Addon detail](../mockups/shell/catalog.html),
  [Preferences](../mockups/shell/preferences.html), and
  [Menu bar](../mockups/shell/menu.html); older launcher/catalog
  artboards are historical.

