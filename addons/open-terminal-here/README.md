# Open Terminal Here

Opens the last-picked terminal app at the front Finder folder (parent if a file is selected). Default app is Terminal. No picker in this version — write the app name to `~/.local/share/jugnu/state/open-terminal-here/app` or wait for the later chooser.

```bash
echo '{"api":1,"op":"run","command":"open","args":{}}' | ./bin/run
```

No Python. Needs Automation permission for Finder on first run.
