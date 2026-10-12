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


def read_as_plain_text() -> str:
    """Read the pasteboard and coerce RTF/HTML source through textutil.

    pbpaste's default flavor is RTF/HTML source verbatim when no plain-text
    flavor exists on the pasteboard (e.g. copying styled text from Pages) —
    read_text() would return that markup as-is. textutil parses it back to
    plain text; when the source is already plain (or textutil is missing),
    the conversion is a no-op passthrough.
    """
    try:
        pbpaste = subprocess.run(["pbpaste"], check=False, capture_output=True)
    except OSError as exc:
        raise ClipboardError("clipboard read failed") from exc
    if pbpaste.returncode != 0:
        raise ClipboardError("clipboard read failed")
    raw = pbpaste.stdout

    try:
        textutil = subprocess.run(
            ["textutil", "-convert", "txt", "-stdin", "-stdout"],
            input=raw,
            check=False,
            capture_output=True,
        )
    except OSError:
        return raw.decode("utf-8", errors="replace")
    if textutil.returncode != 0 or not textutil.stdout:
        return raw.decode("utf-8", errors="replace")
    return textutil.stdout.decode("utf-8", errors="replace")


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
