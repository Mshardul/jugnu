"""Encode / decode / hash / jwt / url / html."""

from __future__ import annotations

import base64
import hashlib
import html
import json
import re
import urllib.parse
from pathlib import Path

from .lines import OpError


def base64_encode(text: str, _args: dict) -> tuple[str, str]:
    return base64.b64encode(text.encode("utf-8")).decode("ascii"), "Base64 encode"


def base64_decode(text: str, _args: dict) -> tuple[str, str]:
    try:
        raw = base64.b64decode(text.strip(), validate=False)
    except Exception as exc:
        raise OpError("invalid Base64") from exc
    try:
        return raw.decode("utf-8"), "Base64 decode"
    except UnicodeDecodeError:
        return raw.decode("utf-8", errors="replace"), "Base64 decode (lossy)"


def url_encode(text: str, _args: dict) -> tuple[str, str]:
    return urllib.parse.quote(text, safe=""), "URL encode"


def url_decode(text: str, _args: dict) -> tuple[str, str]:
    return urllib.parse.unquote(text), "URL decode"


def html_escape(text: str, _args: dict) -> tuple[str, str]:
    return html.escape(text, quote=True), "HTML escape"


def html_unescape(text: str, _args: dict) -> tuple[str, str]:
    return html.unescape(text), "HTML unescape"


def jwt_decode(text: str, _args: dict) -> tuple[str, str]:
    parts = text.strip().split(".")
    if len(parts) < 2:
        raise OpError("not a JWT (need header.payload)")

    def _b64url(segment: str) -> bytes:
        pad = "=" * (-len(segment) % 4)
        return base64.urlsafe_b64decode(segment + pad)

    try:
        header = json.loads(_b64url(parts[0]))
        payload = json.loads(_b64url(parts[1]))
    except Exception as exc:
        raise OpError("could not decode JWT segments") from exc
    out = {"header": header, "payload": payload}
    return json.dumps(out, indent=2, ensure_ascii=False) + "\n", "JWT decode (unverified)"


def hash_text(text: str, args: dict) -> tuple[str, str]:
    algo = args.get("algo", "sha256")
    if not isinstance(algo, str):
        raise OpError("algo must be a string")
    algo = algo.lower()
    if algo not in hashlib.algorithms_available:
        raise OpError(f"unknown hash algo: {algo}")
    # If clipboard looks like an existing file path, hash file bytes
    candidate = text.strip()
    if candidate and "\n" not in candidate and Path(candidate).is_file():
        h = hashlib.new(algo)
        with open(candidate, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest(), f"{algo} file"
    h = hashlib.new(algo)
    h.update(text.encode("utf-8"))
    return h.hexdigest(), f"{algo} text"


_SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(text: str, _args: dict) -> tuple[str, str]:
    s = text.strip().lower()
    s = _SLUG_RE.sub("-", s).strip("-")
    return s, "Slugify"
