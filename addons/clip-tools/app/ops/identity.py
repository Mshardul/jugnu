"""Identity / timestamp / uuid generators."""

from __future__ import annotations

import datetime as dt
import uuid as uuid_mod

from .lines import OpError


def uuid_gen(text: str, args: dict) -> tuple[str, str]:
    kind = args.get("kind", "uuid4")
    if not isinstance(kind, str):
        raise OpError("kind must be a string")
    kind = kind.lower()
    if kind in ("uuid", "uuid4", "v4"):
        return str(uuid_mod.uuid4()), "UUID4"
    if kind in ("ulid",):
        # ULID-ish: time-sortable hex without full Crockford alphabet dependency
        # Use uuid7-style timestamp prefix if available (3.12+ has no uuid7 until 3.13)
        # Fallback: timestamp ms + random
        ms = int(dt.datetime.now(dt.timezone.utc).timestamp() * 1000)
        return f"{ms:012x}{uuid_mod.uuid4().hex[:20]}", "ULID-like"
    if kind in ("nanoid", "nano"):
        alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_-"
        raw = uuid_mod.uuid4().bytes + uuid_mod.uuid4().bytes
        return "".join(alphabet[b % 64] for b in raw[:21]), "nanoid"
    raise OpError(f"unknown uuid kind: {kind}")


def timestamp(text: str, args: dict) -> tuple[str, str]:
    fmt = args.get("format", "iso")
    if not isinstance(fmt, str):
        raise OpError("format must be a string")
    now = dt.datetime.now(dt.timezone.utc)
    local = now.astimezone()
    fmt = fmt.lower()
    if fmt in ("unix", "epoch"):
        return str(int(now.timestamp())), "Unix timestamp"
    if fmt in ("iso", "iso8601"):
        return now.replace(microsecond=0).isoformat().replace("+00:00", "Z"), "ISO-8601 UTC"
    if fmt in ("rfc3339",):
        return now.replace(microsecond=0).isoformat(), "RFC3339"
    if fmt in ("local",):
        return local.replace(microsecond=0).isoformat(), "Local time"
    raise OpError(f"unknown timestamp format: {fmt}")


def iso_week(_text: str, _args: dict) -> tuple[str, str]:
    today = dt.date.today()
    iso = today.isocalendar()
    out = f"{iso.year}-W{iso.week:02d}"
    return out, f"ISO week {out}"
