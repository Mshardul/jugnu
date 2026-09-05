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
    *,
    finder_ok: bool = True,
    finder_path: str = "/tmp/project",
    open_fails: bool = False,
    extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "open.log"
    _write_exec(
        bin_dir / "osascript",
        "#!/bin/bash\n"
        + (f'echo "{finder_path}"\nexit 0\n' if finder_ok else "echo no window >&2\nexit 1\n"),
    )
    _write_exec(
        bin_dir / "open",
        "#!/bin/bash\n"
        + ("exit 1\n" if open_fails else f'printf "%s\\n" "$@" >> "{log}"\nexit 0\n'),
    )
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["OSASCRIPT"] = str(bin_dir / "osascript")
    env["HOME"] = str(tmp_path / "home")
    env["JUGNU_STATE_DIR"] = str(tmp_path / "state")
    if extra_env:
        env.update(extra_env)
    (tmp_path / "home").mkdir()
    return subprocess.run(
        [str(RUN)],
        input='{"api":1,"op":"run","command":"open","args":{}}\n',
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_open_uses_terminal_when_no_saved_app(tmp_path: Path) -> None:
    proc = _run(tmp_path)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    log = (tmp_path / "open.log").read_text(encoding="utf-8")
    assert "-a\nTerminal\n/tmp/project\n" in log


def test_open_uses_last_picked_app(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    (state / "app").write_text("iTerm\n", encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    log = (tmp_path / "open.log").read_text(encoding="utf-8")
    assert "-a\niTerm\n/tmp/project\n" in log


def test_open_errors_without_finder_window(tmp_path: Path) -> None:
    proc = _run(tmp_path, finder_ok=False)
    assert proc.returncode == 0
    payload = json.loads(proc.stdout)
    assert payload["ok"] is False
    assert "Finder" in payload["error"]
    assert not (tmp_path / "open.log").exists()
