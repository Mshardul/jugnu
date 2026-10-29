from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]
RUN = ADDON / "bin" / "run"


def _write_exec(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


def _run(tmp_path: Path, args: dict | None = None) -> subprocess.CompletedProcess[str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    log = tmp_path / "open.log"
    _write_exec(
        bin_dir / "open",
        "#!/bin/bash\n" + f'printf "%s\\n" "$@" >> "{log}"\nexit 0\n',
    )
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["HOME"] = str(tmp_path / "home")
    (tmp_path / "home").mkdir(exist_ok=True)
    payload = {
        "api": 1,
        "op": "run",
        "command": "temporary-folder",
        "args": args or {},
    }
    return subprocess.run(
        [str(RUN)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_creates_folder_and_returns_tray(tmp_path: Path) -> None:
    proc = _run(tmp_path)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["ui"]["pattern"] == "tray"
    assert payload["ui"]["title"] == "Temporary"
    assert payload["ui"]["items"] == []
    assert (tmp_path / "home" / "Temporary").is_dir()
    assert not (tmp_path / "open.log").exists()


def test_lists_existing_files_and_leaves_them(tmp_path: Path) -> None:
    folder = tmp_path / "home" / "Temporary"
    folder.mkdir(parents=True)
    kept = folder / "keep.txt"
    kept.write_text("stay", encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ui"]["items"] == [{"id": str(folder / "keep.txt"), "title": "keep.txt"}]
    proc = _run(tmp_path)
    assert proc.returncode == 0, proc.stderr
    assert kept.read_text(encoding="utf-8") == "stay"


def test_drop_copies_file_and_leaves_the_original(tmp_path: Path) -> None:
    source = tmp_path / "desk" / "note.txt"
    source.parent.mkdir()
    source.write_text("hello", encoding="utf-8")
    proc = _run(tmp_path, {"paths": [str(source)]})
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    copied = tmp_path / "home" / "Temporary" / "note.txt"
    assert copied.read_text(encoding="utf-8") == "hello"
    assert source.read_text(encoding="utf-8") == "hello"
    assert payload["ui"]["items"] == [{"id": str(copied), "title": "note.txt"}]


def test_drop_copies_a_folder(tmp_path: Path) -> None:
    source = tmp_path / "desk" / "Album"
    source.mkdir(parents=True)
    (source / "a.txt").write_text("a", encoding="utf-8")
    proc = _run(tmp_path, {"paths": [str(source)]})
    assert proc.returncode == 0, proc.stderr
    copied = tmp_path / "home" / "Temporary" / "Album" / "a.txt"
    assert copied.read_text(encoding="utf-8") == "a"
    assert (source / "a.txt").read_text(encoding="utf-8") == "a"


def test_drop_does_not_overwrite_an_existing_name(tmp_path: Path) -> None:
    folder = tmp_path / "home" / "Temporary"
    folder.mkdir(parents=True)
    (folder / "keep.txt").write_text("stay", encoding="utf-8")
    source = tmp_path / "desk" / "keep.txt"
    source.parent.mkdir()
    source.write_text("new", encoding="utf-8")
    proc = _run(tmp_path, {"paths": [str(source)]})
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert (folder / "keep.txt").read_text(encoding="utf-8") == "stay"
    assert (folder / "keep 2.txt").read_text(encoding="utf-8") == "new"
    titles = [item["title"] for item in payload["ui"]["items"]]
    assert titles == ["keep 2.txt", "keep.txt"]


def test_delete_moves_selected_files_to_the_trash(tmp_path: Path) -> None:
    folder = tmp_path / "home" / "Temporary"
    folder.mkdir(parents=True)
    doomed = folder / "gone.txt"
    kept = folder / "keep.txt"
    doomed.write_text("bye", encoding="utf-8")
    kept.write_text("stay", encoding="utf-8")
    proc = _run(tmp_path, {"action": "delete", "paths": [str(doomed)]})
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert not doomed.exists()
    assert kept.read_text(encoding="utf-8") == "stay"
    assert payload["ui"]["items"] == [{"id": str(kept), "title": "keep.txt"}]
    trashed = Path.home() / ".Trash" / "gone.txt"
    if trashed.exists():
        trashed.unlink()


def test_delete_can_clear_every_file(tmp_path: Path) -> None:
    folder = tmp_path / "home" / "Temporary"
    folder.mkdir(parents=True)
    first = folder / "one.txt"
    second = folder / "two.txt"
    first.write_text("1", encoding="utf-8")
    second.write_text("2", encoding="utf-8")
    proc = _run(tmp_path, {"action": "delete", "paths": [str(first), str(second)]})
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["ui"]["items"] == []
    assert list(folder.iterdir()) == []
    for name in ("one.txt", "two.txt"):
        trashed = Path.home() / ".Trash" / name
        if trashed.exists():
            trashed.unlink()


def test_delete_refuses_a_path_outside_the_folder(tmp_path: Path) -> None:
    folder = tmp_path / "home" / "Temporary"
    folder.mkdir(parents=True)
    kept = folder / "keep.txt"
    kept.write_text("stay", encoding="utf-8")
    outside = tmp_path / "desk" / "leave.txt"
    outside.parent.mkdir()
    outside.write_text("safe", encoding="utf-8")
    proc = _run(tmp_path, {"action": "delete", "paths": [str(outside), str(folder)]})
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is False
    assert outside.read_text(encoding="utf-8") == "safe"
    assert folder.is_dir()
    assert kept.read_text(encoding="utf-8") == "stay"


def test_drop_of_a_file_already_inside_does_not_duplicate_it(tmp_path: Path) -> None:
    folder = tmp_path / "home" / "Temporary"
    folder.mkdir(parents=True)
    kept = folder / "keep.txt"
    kept.write_text("stay", encoding="utf-8")
    proc = _run(tmp_path, {"paths": [str(kept)]})
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ui"]["items"] == [{"id": str(kept), "title": "keep.txt"}]
    assert list(folder.iterdir()) == [kept]
