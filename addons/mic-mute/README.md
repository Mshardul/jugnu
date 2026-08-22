# Mic Mute

Toggles the macOS **input volume** between 0 and 75 (a practical mute/unmute without CoreAudio frameworks).

```bash
echo '{"api":1,"op":"run","command":"toggle","args":{}}' | ./bin/run
```

No Python. Requires Automation permission for `osascript` volume settings on first run.
