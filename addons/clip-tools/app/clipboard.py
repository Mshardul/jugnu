"""Clipboard read/write via pbpaste / pbcopy."""

from __future__ import annotations

import subprocess


class ClipboardError(Exception):
    pass


def read_text() -> str:
    try:
        proc = subprocess.run(
            ["pbpaste"],
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        raise ClipboardError("clipboard read failed") from exc
    if proc.returncode != 0:
        raise ClipboardError("clipboard read failed")
    return proc.stdout.decode("utf-8", errors="replace")


def write_text(text: str) -> None:
    try:
        proc = subprocess.run(
            ["pbcopy"],
            input=text.encode("utf-8"),
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        raise ClipboardError("clipboard write failed") from exc
    if proc.returncode != 0:
        raise ClipboardError("clipboard write failed")
