from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]
RUN = ADDON / "bin" / "run"
REQUEST = '{"api":1,"op":"run","command":"open","args":{}}\n'


def _run(home: Path, request: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    return subprocess.run(
        [str(RUN)],
        input=request,
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_open_restores_saved_text(tmp_path: Path) -> None:
    home = tmp_path / "home"
    home.mkdir()
    save = (
        '{"api":1,"op":"run","command":"open","args":{"content":"line one\\nline two"}}\n'
    )
    saved = _run(home, save)
    assert saved.returncode == 0, saved.stderr
    assert json.loads(saved.stdout) == {"ok": True, "message": "saved"}

    opened = _run(home, REQUEST)
    assert opened.returncode == 0, opened.stderr
    payload = json.loads(opened.stdout)
    assert payload["ok"] is True
    assert payload["ui"]["pattern"] == "note"
    assert payload["ui"]["title"] == "Temporary note"
    assert payload["ui"]["content"] == "line one\nline two"
    note = home / ".local/share/jugnu/state/floating-note/note.txt"
    assert note.read_text(encoding="utf-8") == "line one\nline two"


def test_open_empty_when_no_file(tmp_path: Path) -> None:
    home = tmp_path / "home"
    home.mkdir()
    opened = _run(home, REQUEST)
    assert opened.returncode == 0, opened.stderr
    payload = json.loads(opened.stdout)
    assert payload["ui"]["title"] == "Temporary note"
    assert payload["ui"]["content"] == ""
