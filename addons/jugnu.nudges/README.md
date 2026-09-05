# Nudges

Nudges shows lightweight reminder cards on repeating timers. It starts with
presets for eye rest, water, and stretching; each waits one full interval
before its first card.

Use **Pause nudges** and **Resume nudges** to control the group, or **Restore
nudge presets** to re-add missing defaults. **Nudge now** previews any enabled
nudge.

Advanced settings use the new-nudge template stored at
`~/.local/share/jugnu/state/nudges/nudges.yaml`.

The file is intentionally small, human-editable YAML:

```yaml
template:
  emoji: "✨"
  title: "New nudge"
  message: "A small reminder."
  interval_minutes: 30
  accent: null
rows:
  - id: "water"
    emoji: "💧"
    title: "Water"
    message: "Your cells called. They’re thirsty."
    interval_minutes: 45
    accent: null
    enabled: true
```

Each row needs a unique `id`, display strings, a positive
`interval_minutes`, and `enabled`. `accent` is either `null` or a shell card
accent such as `"#66CCFF"`. Jugnu reconciles enabled rows with the shared clock
whenever a Nudges command runs. Restoring presets only adds preset IDs absent
from this file.

Smoke the management list with the clock helper installed:

```bash
echo '{"api":1,"op":"run","command":"manage","args":{}}' | JUGNU_HELPER_CLOCK=/path/to/helper/root addons/jugnu.nudges/bin/run
```

Expected: an `ok` response with a `list` UI containing nudge rows and an Add
row.
