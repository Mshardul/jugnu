# Focus Toggle

Best-effort Focus / Do Not Disturb toggle:

1. Runs a matching **Shortcuts** shortcut if one exists.
2. Otherwise clicks Control Center’s Focus menu item via System Events.

```bash
echo '{"api":1,"op":"run","command":"toggle","args":{}}' | ./bin/run
```

May need Accessibility / Automation permission. Create a Shortcut named “Focus” or “Do Not Disturb” for the most reliable path.
