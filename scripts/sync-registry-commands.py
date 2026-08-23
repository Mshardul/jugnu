#!/usr/bin/env python3
"""Regenerate `commands` on every registry/addons.json entry from addon.yaml.

Only ever touches `commands` — never category/tags/description/summary/version/url/sha256.

usage: scripts/sync-registry-commands.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


class ManifestParseError(Exception):
    pass


def parse_yaml_scalar(raw: str) -> str:
    text = raw.strip()
    if len(text) >= 2 and text[0] == text[-1] == '"':
        inner = text[1:-1]
        return (
            inner.replace("\\\\", "\0")
            .replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\t", "\t")
            .replace("\0", "\\")
        )
    if len(text) >= 2 and text[0] == text[-1] == "'":
        return text[1:-1].replace("''", "'")
    if " #" in text:
        text = text[: text.index(" #")].rstrip()
    return text


def extract_commands(manifest_text: str) -> list[dict[str, str]]:
    lines = manifest_text.splitlines()
    in_commands = False
    items: list[dict[str, str]] = []
    current: dict[str, str] | None = None

    def flush() -> None:
        nonlocal current
        if current is None:
            return
        if "id" not in current or "title" not in current:
            raise ManifestParseError(f"command missing id or title: {current}")
        items.append(
            {
                "id": current["id"],
                "title": current["title"],
                "subtitle": current.get("subtitle", ""),
            }
        )
        current = None

    for line in lines:
        if not in_commands:
            if line.startswith("commands:"):
                in_commands = True
            continue
        stripped = line.lstrip(" ")
        if stripped == "" or stripped.startswith("#"):
            continue
        indent = len(line) - len(stripped)
        if indent == 0:
            break
        if stripped.startswith("- "):
            flush()
            current = {}
            rest = stripped[2:]
            if ":" in rest:
                key, _, value = rest.partition(":")
                current[key.strip()] = parse_yaml_scalar(value)
            continue
        if current is not None and ":" in stripped:
            key, _, value = stripped.partition(":")
            current[key.strip()] = parse_yaml_scalar(value)

    flush()
    if not in_commands:
        raise ManifestParseError("no commands: block")
    return items


def sync_registry(registry_file: Path, repo_root: Path, check_mode: bool) -> int:
    original_text = registry_file.read_text()
    entries = json.loads(original_text)
    errors: list[str] = []

    for entry in entries:
        addon_id = entry["id"]
        manifest = repo_root / "addons" / addon_id / "addon.yaml"
        if not manifest.is_file():
            errors.append(f"missing manifest {manifest}")
            continue
        try:
            entry["commands"] = extract_commands(manifest.read_text())
        except ManifestParseError as exc:
            errors.append(f"{manifest}: {exc}")

    if errors:
        for message in errors:
            sys.stderr.write(f"error: {message}\n")
        return 1

    new_text = json.dumps(entries, indent=2) + "\n"
    if check_mode:
        if new_text != original_text:
            sys.stderr.write(
                "registry/addons.json commands are stale — run scripts/sync-registry-commands.sh\n"
            )
            return 1
        return 0

    registry_file.write_text(new_text)
    return 0


def _self_test() -> int:
    missing_subtitle = extract_commands(
        "id: x\ncommands:\n  - id: status\n    title: World's status\nentrypoint:\n  kind: exec\n"
    )
    assert missing_subtitle == [
        {"id": "status", "title": "World's status", "subtitle": ""}
    ], missing_subtitle

    quoted = extract_commands(
        'commands:\n  - id: a\n    title: "World\'s status"\n    subtitle: "Say \\"hi\\""\n'
    )
    assert quoted[0]["title"] == "World's status", quoted
    assert quoted[0]["subtitle"] == 'Say "hi"', quoted
    encoded = json.dumps(quoted)
    json.loads(encoded)

    title_after_subtitle = extract_commands(
        "commands:\n  - id: a\n    subtitle: later title is fine\n    title: Hello\n"
    )
    assert title_after_subtitle[0]["title"] == "Hello"
    assert title_after_subtitle[0]["subtitle"] == "later title is fine"

    try:
        extract_commands("commands:\n  - id: a\n    keywords: [x]\n")
    except ManifestParseError:
        pass
    else:
        raise AssertionError("expected missing title to fail")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return _self_test()
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    check_mode = "--check" in argv
    return sync_registry(repo_root / "registry" / "addons.json", repo_root, check_mode)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
