"""YAML transforms via vendored PyYAML (pure Python)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from .lines import OpError

_VENDOR = Path(__file__).resolve().parents[1] / "vendor"
if str(_VENDOR) not in sys.path:
    sys.path.insert(0, str(_VENDOR))

import yaml  # noqa: E402  # vendored


def yaml_pretty(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise OpError(f"invalid YAML: {exc}") from exc
    out = yaml.safe_dump(data, sort_keys=False, allow_unicode=True)
    return out, "YAML pretty"


def yaml_json(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise OpError(f"invalid YAML: {exc}") from exc
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n", "YAML → JSON"


def json_yaml(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    out = yaml.safe_dump(data, sort_keys=False, allow_unicode=True)
    return out, "JSON → YAML"
