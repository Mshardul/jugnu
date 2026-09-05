from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]
RUN = ADDON / "bin" / "run"


def _write_exec(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


def _run(
    tmp_path: Path,
    payload: dict[str, object],
    *,
    helper: bool = True,
) -> tuple[subprocess.CompletedProcess[str], Path]:
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["HOME"] = str(home)
    clock_log = tmp_path / "clock.log"
    if helper:
        helper_root = tmp_path / "clock-helper"
        _write_exec(
            helper_root / "bin" / "clock",
            f"""#!/bin/bash
request=$(cat)
printf '%s\\n' "$request" >> "{clock_log}"
printf '{{"ok":true}}\\n'
""",
        )
        env["JUGNU_HELPER_CLOCK"] = str(helper_root)
    else:
        env["JUGNU_HELPER_CLOCK"] = str(tmp_path / "missing")
    proc = subprocess.run(
        [str(RUN)],
        input=json.dumps(payload) + "\n",
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    return proc, clock_log


def test_work_upserts_one_shot(tmp_path: Path) -> None:
    proc, clock_log = _run(tmp_path, {"api": 1, "op": "run", "command": "work"})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert "work started" in body["message"]
    logged = clock_log.read_text(encoding="utf-8")
    assert '"op":"upsert"' in logged
    assert '"kind":"one-shot"' in logged
    assert '"command":"chime"' in logged
    state = tmp_path / "home" / ".local" / "share" / "jugnu" / "state" / "pomodoro" / "state.json"
    assert state.exists()


def test_reset_cancels_timer(tmp_path: Path) -> None:
    first, _ = _run(tmp_path, {"api": 1, "op": "run", "command": "work"})
    assert first.returncode == 0, first.stderr
    proc, clock_log = _run(tmp_path, {"api": 1, "op": "run", "command": "reset"})
    assert proc.returncode == 0, proc.stderr
    logged = clock_log.read_text(encoding="utf-8")
    assert '"op":"cancel"' in logged
    state = tmp_path / "home" / ".local" / "share" / "jugnu" / "state" / "pomodoro" / "state.json"
    assert not state.exists()


def test_missing_helper_fails(tmp_path: Path) -> None:
    proc, _ = _run(tmp_path, {"api": 1, "op": "run", "command": "work"}, helper=False)
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is False


def test_chime_clears_state(tmp_path: Path) -> None:
    state_dir = tmp_path / "home" / ".local" / "share" / "jugnu" / "state" / "pomodoro"
    state_dir.mkdir(parents=True)
    (state_dir / "state.json").write_text('{"phase":"work","end_ts":9999999999}\n', encoding="utf-8")
    proc, _ = _run(tmp_path, {"api": 1, "op": "run", "command": "chime"})
    assert proc.returncode == 0, proc.stderr
    body = json.loads(proc.stdout)
    assert body["ok"] is True
    assert not (state_dir / "state.json").exists()


def test_entrypoint_has_no_disown() -> None:
    text = RUN.read_text(encoding="utf-8")
    assert "disown" not in text
    assert "nohup" not in text
