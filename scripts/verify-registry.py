#!/usr/bin/env python3
"""Prove every registry row points at a real, matching release asset.

Checks registry/addons.json, registry/helpers.json, and registry/jugnu-app.json the way the shell
will: HTTPS on the install host allowlist, a well-formed sha256, then (unless --offline) downloads
each asset and compares the hash and the packaged id/version with the row.

usage: scripts/verify-registry.py [--offline] [--self-test] [addon|helper|app ...]

Naming kinds limits the check to those rows; default is all three.
"""

from __future__ import annotations

import hashlib
import io
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path
from urllib.parse import urlparse

# Mirrors InstallHostAllowlist.hosts in the shell.
ALLOWED_HOSTS = {
    "github.com",
    "objects.githubusercontent.com",
    "release-assets.githubusercontent.com",
    "github-releases.githubusercontent.com",
}
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
SHA256_HEX = re.compile(r"^[0-9a-f]{64}$")


def is_well_formed_sha256(value: str) -> bool:
    lower = value.lower()
    return bool(SHA256_HEX.match(lower)) and set(lower) != {"0"}


def is_allowed_url(url: str) -> bool:
    parsed = urlparse(url)
    return parsed.scheme == "https" and (parsed.hostname or "").lower() in ALLOWED_HOSTS


def manifest_value(text: str, key: str) -> str | None:
    for line in text.splitlines():
        if line.startswith(f"{key}:"):
            value = line.split(":", 1)[1].split(" #", 1)[0].strip()
            return value.strip("\"'")
    return None


def row_errors(row: dict, label: str) -> list[str]:
    errors = []
    if not SEMVER.match(str(row.get("version", ""))):
        errors.append(f"{label}: version {row.get('version')!r} is not SemVer")
    if not is_allowed_url(str(row.get("url", ""))):
        errors.append(f"{label}: url {row.get('url')!r} is not an allowlisted HTTPS release asset")
    if not is_well_formed_sha256(str(row.get("sha256", ""))):
        errors.append(f"{label}: sha256 {row.get('sha256')!r} is not 64 hex digits or is all 0s")
    return errors


def package_errors(kind: str, row: dict, label: str, data: bytes) -> list[str]:
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile:
        return [f"{label}: asset is not a zip"]
    names = [n for n in archive.namelist() if not n.startswith("__MACOSX/")]

    if kind == "app":
        roots = {n.split("/")[0] for n in names}
        plists = [n for n in names if n.endswith("Jugnu.app/Contents/Info.plist")]
        if len(plists) != 1 or plists[0].count("/") > 3 or len(roots) != 1:
            return [f"{label}: zip must hold exactly one Jugnu.app at the root"]
        return []

    manifest_name = "addon.yaml" if kind == "addon" else "helper.yaml"
    if kind == "addon":
        roots = {n.split("/")[0] for n in names}
        if roots != {row["id"]}:
            return [f"{label}: zip root must be exactly {row['id']}/, found {sorted(roots)}"]
        manifest_path = f"{row['id']}/{manifest_name}"
    else:
        manifest_path = manifest_name
    if manifest_path not in names:
        return [f"{label}: zip has no {manifest_path}"]
    text = archive.read(manifest_path).decode("utf-8", "replace")
    errors = []
    for key in ("id", "version"):
        packaged = manifest_value(text, key)
        if packaged != row[key]:
            errors.append(f"{label}: packaged {key} {packaged!r} != registry {row[key]!r}")
    return errors


def download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as response:
        final = response.geturl()
        if not is_allowed_url(final):
            raise ValueError(f"redirected off the allowlist to {final}")
        return response.read()


KINDS = ("addon", "helper", "app")


def verify(registry_dir: Path, offline: bool, kinds: tuple[str, ...] = KINDS) -> list[str]:
    rows: list[tuple[str, dict]] = []
    if "addon" in kinds:
        rows += [("addon", r) for r in json.loads((registry_dir / "addons.json").read_text())]
    if "helper" in kinds:
        rows += [("helper", r) for r in json.loads((registry_dir / "helpers.json").read_text())]
    if "app" in kinds:
        rows.append(("app", json.loads((registry_dir / "jugnu-app.json").read_text())))

    errors: list[str] = []
    for kind, row in rows:
        label = f"{kind} {row.get('id')} {row.get('version')}"
        if kind == "app" and row.get("id") != "jugnu.shell":
            errors.append(f"{label}: id must be jugnu.shell")
        found = row_errors(row, label)
        errors += found
        if offline or found:
            continue
        try:
            data = download(row["url"])
        except Exception as exc:  # noqa: BLE001 — any fetch failure is a broken row
            errors.append(f"{label}: download failed: {exc}")
            continue
        actual = hashlib.sha256(data).hexdigest()
        if actual != row["sha256"].lower():
            errors.append(f"{label}: sha256 mismatch (registry {row['sha256']}, asset {actual})")
            continue
        errors += package_errors(kind, row, label, data)
    return errors


def _zip(files: dict[str, str]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, body in files.items():
            archive.writestr(name, body)
    return buffer.getvalue()


def _self_test() -> int:
    good = "ab" * 32
    assert is_well_formed_sha256(good)
    assert is_well_formed_sha256(good.upper())
    for bad in ("", "deadbeef", "0" * 64, "g" * 64, "a" * 65, "PLACEHOLDER-run-scripts"):
        assert not is_well_formed_sha256(bad), bad

    assert is_allowed_url("https://github.com/Mshardul/jugnu/releases/download/t/a.zip")
    for bad in ("http://github.com/a.zip", "https://evil.example/a.zip", "PLACEHOLDER", ""):
        assert not is_allowed_url(bad), bad

    row = {"id": "jugnu.x", "version": "1.0.0", "url": "PLACEHOLDER", "sha256": "PLACEHOLDER"}
    assert len(row_errors(row, "x")) == 2

    addon = {"id": "jugnu.x", "version": "1.2.0"}
    ok = _zip({"jugnu.x/addon.yaml": "id: jugnu.x\nversion: 1.2.0\n", "jugnu.x/bin/run": ""})
    assert package_errors("addon", addon, "x", ok) == []
    stale = _zip({"jugnu.x/addon.yaml": "id: jugnu.x\nversion: 1.0.0\n"})
    assert any("version" in e for e in package_errors("addon", addon, "x", stale))
    two_roots = _zip({"jugnu.x/addon.yaml": "id: jugnu.x\nversion: 1.2.0\n", "other/f": ""})
    assert any("root" in e for e in package_errors("addon", addon, "x", two_roots))

    helper = {"id": "clock", "version": "1.0.0"}
    helper_zip = _zip({"helper.yaml": 'id: clock\nversion: "1.0.0"\n', "bin/clock": ""})
    assert package_errors("helper", helper, "h", helper_zip) == []

    app_zip = _zip({"Jugnu.app/Contents/Info.plist": "<plist/>"})
    assert package_errors("app", {"id": "jugnu.shell"}, "a", app_zip) == []
    assert package_errors("app", {"id": "jugnu.shell"}, "a", _zip({"x.txt": ""})) != []
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return _self_test()
    kinds = tuple(a for a in argv if not a.startswith("--")) or KINDS
    unknown = [k for k in kinds if k not in KINDS]
    if unknown:
        sys.stderr.write(f"unknown kind(s) {unknown}; expected {list(KINDS)}\n")
        return 2
    registry_dir = Path(__file__).resolve().parent.parent / "registry"
    errors = verify(registry_dir, offline="--offline" in argv, kinds=kinds)
    for message in errors:
        sys.stderr.write(f"error: {message}\n")
    if errors:
        sys.stderr.write(
            f"{len(errors)} registry problem(s). Publish through the release workflow; "
            "see docs/release-process.md.\n"
        )
        return 1
    print("registry ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
