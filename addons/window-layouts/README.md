# Window Layouts

First-party window family for Jugnu: snaps, snap board, named zones (max 6, geometry only), Space jump via system shortcuts. **No undo. No scenes.**

Build the helper (required before first invoke — the shell times out at 0.8s):

```bash
make window-layouts
```

`bin/run` execs `bin/helper`. Accessibility is requested on first use of this addon, not at empty-shell launch.

State: `~/.local/share/jugnu/state/window-layouts` (removed on uninstall via `cleanup`).
