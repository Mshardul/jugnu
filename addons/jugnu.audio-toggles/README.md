# Audio

Mic and mute-all status, in one addon (merges the former Mic Mute + Mute All).

```bash
echo '{"api":1,"op":"run","command":"audio-toggles","args":{}}' | ./bin/run
echo '{"api":1,"op":"run","command":"mute-mic","args":{}}' | ./bin/run
echo '{"api":1,"op":"run","command":"mute-all","args":{}}' | ./bin/run
```

- `audio-toggles` — grid panel, two tiles (Microphone, Mute All), live status; tap a tile to toggle it in place.
- `mute-mic` — toggles macOS **input volume** between 0 and 75 (a practical mute/unmute without CoreAudio frameworks).
- `mute-all` — mutes input and output volume together, then restores the saved levels on the next run.

State: `~/.local/share/jugnu/state/audio-toggles/volumes` (removed on disable/uninstall). No Python.
Requires Automation permission for `osascript` volume settings on first run.
