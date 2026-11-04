# Audio Convert

Audio format conversion with the built-in macOS `afconvert` tool: WAV, AIFF, M4A (AAC), CAF, and MP3 as a source.

- **Convert addon:** every command here is also a file converter edge (`modes: [file]`), so *Convert a file* lists these formats automatically.
- **Palette:** run a command to convert the audio files you copied in Finder; each result is saved beside its original and never overwrites.
- MP3 is read-only: macOS has no MP3 encoder. Only `/usr/bin/afconvert` is executed, with an argument list and no shell.
- Needs the shared `python-runtime` helper (`JUGNU_HELPER_PYTHON_RUNTIME`).

Tests: `.venv/bin/python -m pytest addons/jugnu.media-convert`
