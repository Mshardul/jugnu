"""Pytest path setup for leaf packages (module next to tests/)."""

from __future__ import annotations

import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent


def _leaf_roots() -> list[Path]:
    roots: list[Path] = []
    for base in (_ROOT / "apps", _ROOT / "extensions" / "macos"):
        if not base.is_dir():
            continue
        for leaf in sorted(base.iterdir()):
            if leaf.is_dir() and (leaf / "tests").is_dir():
                roots.append(leaf)
    return roots


for _leaf in _leaf_roots():
    path = str(_leaf)
    if path not in sys.path:
        sys.path.insert(0, path)
