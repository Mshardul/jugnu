# Pomodoro

25-minute focus and 5-minute break timers. The deferred chime is a one-shot on the shared `clock` helper, not a background shell.

```bash
echo '{"api":1,"op":"run","command":"work","args":{}}' | ./bin/run
echo '{"api":1,"op":"run","command":"status","args":{}}' | ./bin/run
echo '{"api":1,"op":"run","command":"reset","args":{}}' | ./bin/run
```
