# Document Convert

Document format conversion with the built-in macOS `textutil` tool: Word (DOCX), RTF, OpenDocument (ODT), HTML and plain text.

- **Convert addon:** every command here is also a file converter edge (`modes: [file]`). The addon declares the DOCX, RTF and ODT formats; HTML and plain text are core formats.
- **Palette:** run a command to convert the document files you copied in Finder; each result is saved beside its original and never overwrites.
- `textutil` runs with `-noload`, so a document can never make it fetch remote images or other resources. Only `/usr/bin/textutil` is executed, with an argument list and no shell.
- Needs the shared `python-runtime` helper (`JUGNU_HELPER_PYTHON_RUNTIME`).

Tests: `.venv/bin/python -m pytest addons/jugnu.doc-convert`
