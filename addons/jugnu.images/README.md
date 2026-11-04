# Images

Image format conversion with the built-in macOS `sips` tool: HEIC, JPEG, PNG, TIFF and GIF.

- **Convert addon:** every command here is also a file converter edge (`modes: [file]`), so *Convert a file* lists these formats automatically.
- **Palette:** run a command to convert the image files you copied in Finder; each result is saved beside its original and never overwrites.
- Needs the shared `python-runtime` helper (`JUGNU_HELPER_PYTHON_RUNTIME`). Only `/usr/bin/sips` is executed, with an argument list and no shell.

Tests: `.venv/bin/python -m pytest addons/jugnu.images`
