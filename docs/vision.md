# Jugnu vision

## Metaphor

*Jugnu* is Hindi for firefly. Not Apple’s floodlight (Spotlight) — a small personal light that appears when you call it.

**Tagline direction:** “A little light for everything on your Mac.” / “Glow when you call.”

## Product goal

A Mac **command platform** that can replace Spotlight + Alfred + Raycast for daily command, clipboard, window, and addon workflows — not a thin wrapper around someone else’s launcher.

**Surfaces (locked):** addons are not “palette commands only.” Each job may expose:

1. **Commands** — searchable palette / menu-bar actions
2. **Popup UI** — focused panels, pickers, forms, previews, and status chrome that feel native and intentional
3. **Speed** — first-class; invoke → visible result must feel instant (no sluggish “script runner” feel)
4. **Context later** — intelligent surfacing: the right popup/command offered from what’s on screen / selection / clipboard (design after v0 primitives exist)

Backlog ids name **jobs**; shipping a job implies designing its **UI + latency**, not only a CLI-shaped action.

## Naming

| Surface | Name |
|---|---|
| Display | Jugnu |
| GitHub repo | `jugnu` |
| CLI binary | `jugnu` (preferred) |

Do not invent a second product name or collapse the Tools nursery into Jugnu without an explicit decision.

## Decomposition (locked)

1. **Shell** — hotkey palette, search, addon loader, install/uninstall addons, enable/disable via YAML
2. **Clipboard** — two modes: use-and-throw vs full history; skip concealed pasteboard / password-manager markers
3. **Window management** — deep feature set and strong UX (not only a minimal layout saver)
4. **First-party addons** — meeting/device QoL, file triage, and similar focused jobs
5. **Dev ops in the menu bar** — yes (ports, brew, agents, disk, etc.)

## Addon model

- All-purpose shell; users install/uninstall addons
- Enable/disable in YAML
- Prefer focused addons over one binary of unrelated jobs
- Tools nursery (`cli/`, etc.) stays separate; Jugnu may wrap those tools as addons rather than merging source trees

### Catalog hierarchy (user POV — locked intent)

Think like a user browsing Jugnu, not like a repo of one-line scripts.

| Level | What the user sees | Ship / install unit | Example |
|---|---|---|---|
| **Category** | Browse/group in the app (and registry) | Taxonomy only — not a zip | Clipboard, Meeting, Appearance, Converters, Play |
| **Addon** | An installable tool with a clear job (commands **and/or** popup UI) | **One zip** / one YAML enable key | Dark Mode, Clip Tools, Unit Convert, Play Shelf |
| **Commands** | Actions inside that addon (palette / menu entries) | `commands` in `addon.yaml` — not their own zip | Toggle appearance; Format JSON; JSON → CSV; Roll 2d6 |
| **UI** | Panels, pickers, forms, previews for that addon | Part of the same zip — not a separate product | Process list sorter; emoji search; layout picker; nudge card |

**Packaging rules (user mental model):**

1. **One job → one addon.** Inverse or paired actions share an addon (e.g. light mode + dark mode = **Dark Mode** with toggle/set commands — never two installables).
2. **Same shape of work → multiple commands on one addon.** Converters/formatters belong together (JSON pretty/minify, JSON ↔ CSV, Base64, slugify, timestamps, …) — not a separate zip per transformation. Same for sibling **UI** flows on that job.
3. **Do not club unrelated jobs** just because they are all “toggles” or all “small.” Dock autohide and mic mute are different user jobs; split or group only when a user would expect one tool.
4. **Shared capability between addons — pick one:**
   - If the user would want that capability **on its own** → it is (or becomes) **its own addon**; other addons depend on / invoke it, or the user installs both.
   - If the user would **not** need it as a separate installable → keep it as **shared source** that is **copied/included into each consuming addon’s zip** at package time (not a hidden second product in the registry).
5. Shell **search** lists commands; **install / enable** is per addon; **browse** can use categories; addon **UI** opens from command, hotkey, menu bar, or (later) context.
6. **Name the job** in ids/titles — what the user searches for — not the scenario you pictured while inventing it (`mute-all`, not `call-mute-all`).
7. **UI + speed are part of the job.** A backlog accept is not “ship a silent script”; plan the popup/panel and keep interaction snappy. Context-aware popups come after the shell can host addon UI reliably.

Category names and exact addon boundaries can evolve; Category → Addon → Commands/UI should not. Shared-code packaging (rule 4) is locked intent; exact build plumbing can follow later.

## Relationship to Tools

Jugnu lives in its **own** repo. Staging leaves under `apps/` and `extensions/macos/` were moved or copied from Tools planning. Small independent CLIs remain in Tools unless graduated; Jugnu integrates them as dependencies/wrappers when needed.

## Explicit non-goals (early)

- Rebuilding a general file-search war with Alfred on day one (except as part of designing shell search)
- Merging unrelated Tools CLIs into one Jugnu binary
- TextExpander-class in-app snippet expand before clipboard/hotkey paste paths (Accessibility permission + latency)
