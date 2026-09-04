# Clip Tools

Clipboard text format / convert / line tools. Requires the **`python-runtime`** helper (`JUGNU_HELPER_PYTHON_RUNTIME`).

```bash
export JUGNU_HELPER_PYTHON_RUNTIME="$(cd ../../helpers/python-runtime && pwd)"
echo '{"api":1,"op":"run","command":"json-pretty","args":{}}' | ./bin/run
```

Tests (no live pasteboard — inject mode):

```bash
export JUGNU_HELPER_PYTHON_RUNTIME="$(cd ../../helpers/python-runtime && pwd)"
cd addons/clip-tools
"$JUGNU_HELPER_PYTHON_RUNTIME/bin/python3" -I -m unittest discover -s tests -v
```

Phase 1 is palette one-shots only. Text Transform panel is Phase 2.
