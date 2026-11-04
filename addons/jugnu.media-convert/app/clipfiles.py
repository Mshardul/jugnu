"""Files copied in Finder, read from the general pasteboard (JXA; no shell)."""

from __future__ import annotations

import json
import os
import subprocess

_SCRIPT = """
ObjC.import('AppKit');
const urls = $.NSPasteboard.generalPasteboard.readObjectsForClassesOptions(
  $([$.NSURL]), $({NSPasteboardURLReadingFileURLsOnlyKey: true}));
const out = [];
const count = urls ? urls.count : 0;
for (let i = 0; i < count; i++) {
  out.push(ObjC.unwrap(urls.objectAtIndex(i).path));
}
JSON.stringify(out);
"""


def clipboard_files() -> list[str]:
    """Absolute paths of files on the pasteboard.

    JUGNU_CONVERT_INJECT_PATHS (a JSON list) replaces the pasteboard read in tests.
    """
    injected = os.environ.get("JUGNU_CONVERT_INJECT_PATHS")
    if injected is not None:
        return [p for p in json.loads(injected) if isinstance(p, str)]
    try:
        proc = subprocess.run(
            ["/usr/bin/osascript", "-l", "JavaScript", "-e", _SCRIPT],
            check=False,
            capture_output=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if proc.returncode != 0:
        return []
    try:
        return [p for p in json.loads(proc.stdout.decode("utf-8")) if isinstance(p, str)]
    except (ValueError, UnicodeDecodeError):
        return []
