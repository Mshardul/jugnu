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

## Runtime addon-to-addon calls (MCP-style or similar)

A mechanism for one running addon to call into another at runtime (e.g. a converter addon reading clipboard-history's stored clips directly, rather than through the clipboard). MCP (each addon exposes tools, another addon's process calls them over JSON-RPC) is one possible shape, but heavyweight — a persistent server per addon — for what's mostly small `exec`-and-exit binaries today.

**Origin:** raised while discussing [ticket 0025](tickets.md)'s addon dependency declaration. Explicitly not pursued yet — vision rule 4's "shared capability" case is already resolved at package time (shared source copied into each consuming addon's zip), and no real addon proposal currently needs a *runtime* cross-addon call. Revisit only if a concrete addon design actually needs it; a simpler on-disk shared-state contract (declared paths, like `cleanup.paths` today) is the more likely shape if/when that happens.

**Depends on:** a real addon proposal that needs this, not speculative build-ahead.
