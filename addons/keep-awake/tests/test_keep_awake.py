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


def _run(
    tmp_path: Path,
    payload: dict[str, object],
) -> subprocess.CompletedProcess[str]:
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["JUGNU_STATE_DIR"] = str(tmp_path / "state")
    return subprocess.run(
        [str(RUN)],
        input=json.dumps(payload) + "\n",
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_pick_without_item_returns_duration_list(tmp_path: Path) -> None:
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "pick", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    items = body["ui"]["items"]
    assert [item["id"] for item in items] == ["15m", "1h", "2h", "until"]
    assert "stop" not in [item["id"] for item in items]


def test_pick_15m_writes_timed_session(tmp_path: Path) -> None:
    proc = _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "15m"}},
    )
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "15" in body["message"]
    session = (tmp_path / "state" / "session").read_text(encoding="utf-8")
    assert session.startswith("timed 900 ")
    launch_agents = tmp_path / "home" / "Library" / "LaunchAgents"
    assert not launch_agents.exists() or not any(launch_agents.iterdir())


def test_pick_until_writes_until_session(tmp_path: Path) -> None:
    proc = _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "until"}},
    )
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    session = (tmp_path / "state" / "session").read_text(encoding="utf-8").strip()
    assert session == "until"


def test_active_session_lists_stop_first(tmp_path: Path) -> None:
    first = _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "1h"}},
    )
    assert first.returncode == 0, first.stderr
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "pick", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    ids = [item["id"] for item in body["ui"]["items"]]
    assert ids[0] == "stop"
    assert ids[1:] == ["15m", "1h", "2h", "until"]


def test_stop_clears_session(tmp_path: Path) -> None:
    _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "until"}},
    )
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "stop", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "stop" in body["message"].lower() or "off" in body["message"].lower()
    assert not (tmp_path / "state" / "session").exists()


def test_status_reports_idle_when_no_session(tmp_path: Path) -> None:
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "status", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "off" in body["message"].lower() or "not" in body["message"].lower()


def test_run_does_not_call_launchctl(tmp_path: Path) -> None:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    log = tmp_path / "launchctl.log"
    _write_exec(
        bin_dir / "launchctl",
        f"""#!/bin/bash
printf '%s\\n' "$*" >> "{log}"
exit 0
""",
    )
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["HOME"] = str(home)
    env["JUGNU_STATE_DIR"] = str(tmp_path / "state")
    proc = subprocess.run(
        [str(RUN)],
        input=json.dumps({"api": 1, "op": "run", "command": "pick", "args": {"itemId": "until"}})
        + "\n",
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr
    assert not log.exists()
