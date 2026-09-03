from __future__ import annotations

import json
import os
import sqlite3
import subprocess
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]
RUN = ADDON / "bin" / "run"


def _run(tmp_path: Path, payload: dict[str, object]) -> subprocess.CompletedProcess[str]:
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["HOME"] = str(home)
    return subprocess.run(
        [str(RUN)],
        input=json.dumps(payload) + "\n",
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_list_does_not_write_launchd_plist(tmp_path: Path) -> None:
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "list", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    agents = tmp_path / "home" / "Library" / "LaunchAgents"
    assert not agents.exists() or not any(agents.iterdir())


def test_list_reads_sqlite(tmp_path: Path) -> None:
    db_dir = tmp_path / "home" / ".local" / "share" / "jugnu" / "state" / "clipboard-history"
    db_dir.mkdir(parents=True)
    db = db_dir / "history.db"
    conn = sqlite3.connect(db)
    conn.execute(
        "CREATE TABLE entries (id INTEGER PRIMARY KEY AUTOINCREMENT, ts REAL NOT NULL, text TEXT NOT NULL, pinned INTEGER NOT NULL DEFAULT 0)"
    )
    conn.execute("INSERT INTO entries (ts, text, pinned) VALUES (1, 'hello clip', 0)")
    conn.commit()
    conn.close()
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "list", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ui"]["items"][0]["title"] == "hello clip"
