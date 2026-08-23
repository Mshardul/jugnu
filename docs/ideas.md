# Ideas

Low-confidence future features — not committed, not scoped, not tickets. Revisit this file periodically (no fixed cadence); when an idea firms up enough to actually plan, promote it to a row in [`docs/tickets.md`](tickets.md) and remove it from here. Most of what lands here stays here indefinitely — that's fine, it's meant to be out of the way, not a backlog with obligations attached.

Unlike `tickets.md` (committed future epics with priority/effort/status tracking), this file has no structure requirement — just enough context that a future read understands why the idea existed and what triggered it.

## Secondary actions / hold-modifier preview on palette rows

A Raycast-style actions panel or modifier-key secondary actions on a result row (e.g. hold ⌘ to reveal alternate actions — copy command id, preview effect without running, etc.) instead of Enter always being the only thing a row does.

**Origin:** raised during the 2026-08-23 palette + addon UI product pass epic's feature-discovery pass. Explicitly deferred — real new interaction surface, would have meaningfully grown that epic's scope again after it had already grown substantially in the same session. Revisit once the base palette (search, theming, panels) has shipped and there's a felt sense of "what's missing" from actual use, rather than speculatively building it now.

**Depends on:** the epic above landing first (palette interaction model needs to be stable before layering a second interaction mode on top of it).

## Shaped skeleton placeholders

Replace the current text-only skeleton (`Loading {pattern}…`) with layout-shaped placeholders that match the final List / Form / Confirm chrome (rounded rows, field-shaped bars, confirm-button pair) so the wait state already looks like the panel that will replace it.

**Origin:** raised during the 2026-08-23 palette + addon UI product pass. Explicitly deferred — the epic locked a SwiftUI rewrite of those panels and a shared token set; shaping the skeleton against the *final* layouts is cheaper as a fast-follow than guessing shapes while the panels were still moving.

**Depends on:** that epic’s List / Form / Confirm layouts staying put (tokens, borderless chrome, in-content titles).

## Liquid Glass / Tahoe material chrome on the launcher

Apple’s current glass (`glassEffect` / `NSGlassEffectView`, macOS 26) for the Option+Space panel: glass as **shell chrome**, Firefly / Phosphor / Rose Quartz as the **tint inside**, Reduce Transparency falling back to today’s opaque tokens. Not full-glass cards/sidebar.

**Origin:** raised while locking [shell surface presets](architecture/2026-08-23-shell-surface-presets.md) (ticket 0008). Explicitly deferred — deployment is still macOS 14; real Liquid Glass is 26; identity risk if glass replaces Firefly instead of sitting under it. Revisit after 0008’s one-panel + preset model is real, not before.

**Depends on:** 0008 landing (one morphing panel exists to put glass on).
