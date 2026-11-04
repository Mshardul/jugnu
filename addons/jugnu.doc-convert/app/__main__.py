"""doc-convert router: stdin api:1 JSON -> textutil -> stdout JSON.

`op: convert` (Convert addon) takes `path` and `out`. `op: run` converts the document files
copied in Finder and saves each beside its original. Only /usr/bin/textutil is ever executed,
with an argv list (no shell) and `-noload`, so a document can never make it fetch remote
resources.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from clipfiles import clipboard_files

TEXTUTIL = "/usr/bin/textutil"
TIMEOUT_SECONDS = 60

# format id -> (textutil format name, output extension)
FORMATS: dict[str, tuple[str, str]] = {
    "docx": ("docx", "docx"),
    "rtf": ("rtf", "rtf"),
    "odt": ("odt", "odt"),
    "html": ("html", "html"),
    "plain": ("txt", "txt"),
}

# command id -> (from, to)
EDGES: dict[str, tuple[str, str]] = {
    "docx-plain": ("docx", "plain"),
    "docx-html": ("docx", "html"),
    "docx-rtf": ("docx", "rtf"),
    "docx-odt": ("docx", "odt"),
    "rtf-docx": ("rtf", "docx"),
    "rtf-plain": ("rtf", "plain"),
    "rtf-html": ("rtf", "html"),
    "odt-docx": ("odt", "docx"),
    "odt-plain": ("odt", "plain"),
    "html-docx": ("html", "docx"),
    "html-rtf": ("html", "rtf"),
    "html-plain": ("html", "plain"),
    "plain-docx": ("plain", "docx"),
    "plain-rtf": ("plain", "rtf"),
    "plain-html": ("plain", "html"),
}

_EXT_KIND = {
    "docx": "docx",
    "rtf": "rtf",
    "odt": "odt",
    "html": "html",
    "htm": "html",
    "txt": "plain",
    "text": "plain",
}


class ConvertError(Exception):
    pass


def _emit(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.write("\n")


def convert_file(command: str, src: str, dst: str) -> None:
    if not (os.path.isabs(src) and os.path.isabs(dst)):
        raise ConvertError("paths must be absolute")
    if not os.path.isfile(src):
        raise ConvertError("could not read the document")
    source, target = EDGES[command]
    argv = [
        TEXTUTIL,
        "-noload",
        "-format",
        FORMATS[source][0],
        "-convert",
        FORMATS[target][0],
        "-encoding",
        "UTF-8",
        "-output",
        dst,
        src,
    ]
    try:
        proc = subprocess.run(argv, check=False, capture_output=True, timeout=TIMEOUT_SECONDS)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ConvertError("the document converter could not run") from exc
    if proc.returncode != 0 or not os.path.isfile(dst) or os.path.getsize(dst) == 0:
        raise ConvertError("this document could not be converted")


def _reserve(src: Path, ext: str) -> Path:
    """Collision-free sibling path, created exclusively (never overwrites)."""
    n = 1
    while True:
        name = f"{src.stem}.{ext}" if n == 1 else f"{src.stem} {n}.{ext}"
        target = src.with_name(name)
        try:
            os.close(os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644))
        except FileExistsError:
            n += 1
            continue
        return target


def _kind(path: str) -> str | None:
    return _EXT_KIND.get(Path(path).suffix.lower().lstrip("."))


def _convert_op(req: dict) -> None:
    command = req.get("command")
    edge = EDGES.get(command) if isinstance(command, str) else None
    if edge is None:
        _emit({"ok": False, "error": f"unknown converter: {command}"})
        return
    if (req.get("from"), req.get("to")) != edge:
        _emit({"ok": False, "error": f"{command} converts {edge[0]} to {edge[1]}"})
        return
    src, dst = req.get("path"), req.get("out")
    if not isinstance(src, str) or not isinstance(dst, str) or not src or not dst:
        _emit({"ok": False, "error": "path and out must be strings"})
        return
    try:
        convert_file(command, src, dst)
    except ConvertError as exc:
        _emit({"ok": False, "error": str(exc)})
        return
    _emit({"ok": True, "path": dst})


def _run_op(req: dict) -> None:
    command = req.get("command")
    if command not in EDGES:
        _emit({"ok": False, "error": f"unknown command: {command}"})
        return
    files = [p for p in clipboard_files() if os.path.isfile(p)]
    if not files:
        _emit({"ok": False, "error": "Copy a document file in Finder first."})
        return
    source, target = EDGES[command]
    if any(_kind(p) != source for p in files):
        _emit({"ok": False, "error": f"{command} needs {source.upper()} files."})
        return
    done = 0
    for path in files:
        out = _reserve(Path(path), FORMATS[target][1])
        try:
            convert_file(command, path, str(out))
        except ConvertError as exc:
            out.unlink(missing_ok=True)
            _emit({"ok": False, "error": f"{Path(path).name}: {exc}"})
            return
        done += 1
    _emit({"ok": True, "message": f"Converted {done} file{'s' if done != 1 else ''}."})


def main() -> None:
    raw = sys.stdin.read()
    try:
        req = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        _emit({"ok": False, "error": "invalid request JSON"})
        return
    if req.get("api") != 1:
        _emit({"ok": False, "error": "unsupported api"})
    elif req.get("op") == "convert":
        _convert_op(req)
    elif req.get("op") == "run":
        _run_op(req)
    else:
        _emit({"ok": False, "error": "unsupported op"})


if __name__ == "__main__":
    main()
