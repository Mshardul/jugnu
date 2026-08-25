from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]
RUN = ADDON / "bin" / "run"
LABEL = "com.jugnu.keep-awake"


def _write_exec(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


def _run(
    tmp_path: Path,
    payload: dict[str, object],
) -> subprocess.CompletedProcess[str]:
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
    return subprocess.run(
        [str(RUN)],
        input=json.dumps(payload) + "\n",
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def _plist(tmp_path: Path) -> Path:
    return tmp_path / "home" / "Library" / "LaunchAgents" / f"{LABEL}.plist"


def test_pick_without_item_returns_duration_list(tmp_path: Path) -> None:
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "pick", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    items = body["ui"]["items"]
    assert [item["id"] for item in items] == ["15m", "1h", "2h", "until"]
    assert "stop" not in [item["id"] for item in items]


def test_pick_15m_writes_timed_plist_and_bootstraps(tmp_path: Path) -> None:
    proc = _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "15m"}},
    )
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "15" in body["message"]
    plist = _plist(tmp_path).read_text(encoding="utf-8")
    assert "/usr/bin/caffeinate" in plist
    assert "<string>-di</string>" in plist
    assert "<string>-t</string>" in plist
    assert "<string>900</string>" in plist
    log = (tmp_path / "launchctl.log").read_text(encoding="utf-8")
    assert "bootout" in log
    assert "bootstrap" in log
    assert "kickstart" in log


def test_pick_until_omits_timeout(tmp_path: Path) -> None:
    proc = _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "until"}},
    )
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    plist = _plist(tmp_path).read_text(encoding="utf-8")
    assert "/usr/bin/caffeinate" in plist
    assert "<string>-di</string>" in plist
    assert "-t" not in plist
    assert "KeepAlive" not in plist or "<false/>" in plist


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


def test_stop_unloads_agent(tmp_path: Path) -> None:
    _run(
        tmp_path,
        {"api": 1, "op": "run", "command": "pick", "args": {"itemId": "until"}},
    )
    (tmp_path / "launchctl.log").write_text("", encoding="utf-8")
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "stop", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "stop" in body["message"].lower() or "off" in body["message"].lower()
    log = (tmp_path / "launchctl.log").read_text(encoding="utf-8")
    assert "bootout" in log
    assert not (tmp_path / "state" / "session").exists()


def test_status_reports_idle_when_no_session(tmp_path: Path) -> None:
    proc = _run(tmp_path, {"api": 1, "op": "run", "command": "status", "args": {}})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "off" in body["message"].lower() or "not" in body["message"].lower()
