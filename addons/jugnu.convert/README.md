# Convert

Opens Convert blocks inside the Jugnu frame (`entrypoint.kind: shell`, first-party only).

- **Convert a file** — drop, choose or paste files; pick an output format; get a new file beside each original (never overwrites). Needs an enabled addon that declares `modes: [file]` converters (today: Clip Tools data formats).
- **Convert text** — input on the left, output on the right; the format is detected and can be overridden.

Conversions come from other addons that declare `converters:` (see docs/addon-manifest.md). This addon ships no converter and runs no process of its own.

Spec: docs/architecture/2026-10-30-convert-design.md
