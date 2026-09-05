# Mute All

Mutes input and output volume together, then restores the saved levels on the next run. Does not replace Mic Mute (input only). No menu-bar glyph yet.

```bash
echo '{"api":1,"op":"run","command":"toggle","args":{}}' | ./bin/run
```

State: `~/.local/share/jugnu/state/mute-all/volumes` (removed on disable/uninstall). No Python.
