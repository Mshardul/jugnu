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
    tmp_path: Path, volumes: tuple[str, str] = ("40", "80")
) -> subprocess.CompletedProcess[str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    set_log = tmp_path / "set.log"
    vol_file = tmp_path / "live-volumes"
    if not vol_file.exists():
        vol_file.write_text(f"{volumes[0]}\n{volumes[1]}\n", encoding="utf-8")
    _write_exec(
        bin_dir / "osascript",
        f"""#!/bin/bash
args="$*"
if [[ "$args" == *output\\ volume\\ of* ]] || [[ "$args" == *get\\ volume\\ settings* ]]; then
  cat "{vol_file}"
  exit 0
fi
# Record set volume calls; last two numeric args are output then input in our script.
printf '%s\\n' "$args" >> "{set_log}"
exit 0
""",
    )
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["OSASCRIPT"] = str(bin_dir / "osascript")
    env["HOME"] = str(tmp_path / "home")
    env["JUGNU_STATE_DIR"] = str(tmp_path / "state")
    (tmp_path / "home").mkdir(exist_ok=True)
    return subprocess.run(
        [str(RUN)],
        input='{"api":1,"op":"run","command":"toggle","args":{}}\n',
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_toggle_mutes_and_saves_volumes(tmp_path: Path) -> None:
    proc = _run(tmp_path)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert "muted" in payload["message"].lower()
    state = (tmp_path / "state" / "volumes").read_text(encoding="utf-8")
    assert state.splitlines()[:2] == ["40", "80"]
    sets = (tmp_path / "set.log").read_text(encoding="utf-8")
    assert "output volume 0" in sets
    assert "input volume 0" in sets


def test_toggle_restores_saved_volumes(tmp_path: Path) -> None:
    state_dir = tmp_path / "state"
    state_dir.mkdir()
    (state_dir / "volumes").write_text("40\n80\n", encoding="utf-8")
    proc = _run(tmp_path, volumes=("0", "0"))
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert "restored" in payload["message"].lower()
    assert not (state_dir / "volumes").exists()
    sets = (tmp_path / "set.log").read_text(encoding="utf-8")
    assert "output volume 40" in sets
    assert "input volume 80" in sets
