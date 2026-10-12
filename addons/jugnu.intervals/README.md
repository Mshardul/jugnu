# Intervals

Intervals is one timer list: recurring reminder cards (eye rest, water, stretch,
and any rows you add) and a pomodoro preset that alternates focus and break.

Pomodoro starts disabled. **Start focus session** or **Start break** enables it
and schedules that phase. When the phase ends, the card shows and the other
phase is scheduled. **Reset pomodoro** stops it. **Pomodoro status** reports
the time left.

Use **Pause intervals** and **Resume intervals** for the whole list, or
**Restore interval presets** to re-add missing defaults. **Show interval now**
previews any enabled row.

State lives at `~/.local/share/jugnu/state/intervals/intervals.yaml`.

```bash
echo '{"api":1,"op":"run","command":"manage","args":{}}' | JUGNU_HELPER_CLOCK=/path/to/helper/root addons/jugnu.intervals/bin/run
```

Expected: an `ok` response with a `list` UI containing the preset rows and an
Add row. The pomodoro row is disabled until a focus or break command starts it.
