# Keep Awake

Stops the Mac from idle-sleeping and keeps the display on for 15 minutes, 1 hour, 2 hours, or until you turn it off. Closing the lid can still sleep. Uses macOS `/usr/bin/caffeinate` (already on the machine) behind a LaunchAgent so disable/uninstall can unload it.

```bash
echo '{"api":1,"op":"run","command":"pick","args":{}}' | ./bin/run
echo '{"api":1,"op":"run","command":"pick","args":{"itemId":"15m"}}' | ./bin/run
echo '{"api":1,"op":"run","command":"stop","args":{}}' | ./bin/run
```

One session at a time; picking a new duration replaces the current one. No Python. No Homebrew.
