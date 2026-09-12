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


def _env(tmp_path: Path, osascript_body: str) -> dict[str, str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    _write_exec(bin_dir / "osascript", osascript_body)
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["OSASCRIPT"] = str(bin_dir / "osascript")
    env["HOME"] = str(tmp_path / "home")
    env["JUGNU_STATE_DIR"] = str(tmp_path / "state")
    (tmp_path / "home").mkdir(exist_ok=True)
    return env


def _run(command: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    payload = json.dumps({"api": 1, "op": "run", "command": command, "args": {}})
    return subprocess.run(
        [str(RUN)], input=payload, capture_output=True, text=True, env=env, check=False
    )


def test_router_rejects_unknown_command(tmp_path: Path) -> None:
    env = _env(tmp_path, "#!/bin/bash\nexit 0\n")
    proc = _run("bogus", env)
    assert proc.returncode == 0
    payload = json.loads(proc.stdout)
    assert payload["ok"] is False


def test_mute_mic_toggles(tmp_path: Path) -> None:
    osa_body = """#!/bin/bash
cat <<'APPLESCRIPT_OUT'
muted
APPLESCRIPT_OUT
"""
    env = _env(tmp_path, osa_body)
    proc = _run("mute-mic", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert "mute" in payload["message"].lower()


def test_mute_all_mutes_and_saves(tmp_path: Path) -> None:
    set_log = tmp_path / "set.log"
    vol_file = tmp_path / "live-volumes"
    vol_file.write_text("40\n80\n", encoding="utf-8")
    osa_body = f"""#!/bin/bash
args="$*"
if [[ "$args" == *output\\ volume\\ of* ]] || [[ "$args" == *get\\ volume\\ settings* ]]; then
  cat "{vol_file}"
  exit 0
fi
printf '%s\\n' "$args" >> "{set_log}"
exit 0
"""
    env = _env(tmp_path, osa_body)
    proc = _run("mute-all", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    state = (tmp_path / "state" / "volumes").read_text(encoding="utf-8")
    assert state.splitlines()[:2] == ["40", "80"]


def test_audio_toggles_status_reflects_live_state(tmp_path: Path) -> None:
    osa_body = """#!/bin/bash
echo 0
"""
    env = _env(tmp_path, osa_body)
    proc = _run("audio-toggles", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["ui"]["pattern"] == "grid"
    items = {item["id"]: item for item in payload["ui"]["gridItems"]}
    assert items["mic"]["active"] is True
    assert items["all"]["active"] is False


def test_audio_toggles_status_reflects_mute_all_active(tmp_path: Path) -> None:
    state_dir = tmp_path / "state"
    state_dir.mkdir()
    (state_dir / "volumes").write_text("40\n80\n", encoding="utf-8")
    osa_body = """#!/bin/bash
echo 75
"""
    env = _env(tmp_path, osa_body)
    proc = _run("audio-toggles", env)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    items = {item["id"]: item for item in payload["ui"]["gridItems"]}
    assert items["mic"]["active"] is False
    assert items["all"]["active"] is True
