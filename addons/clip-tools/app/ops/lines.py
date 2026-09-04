"""Line and text-stats transforms."""

from __future__ import annotations

import re


class OpError(Exception):
    pass


def _lines(text: str) -> list[str]:
    if text == "":
        return []
    # Keep trailing empty line only if text ends with newline? Splitlines drops final.
    ends_nl = text.endswith("\n")
    parts = text.splitlines()
    if ends_nl and (not parts or parts[-1] != ""):
        # splitlines already dropped the trailing empty from final \n — fine
        pass
    return parts


def _join(lines: list[str], text: str) -> str:
    if not lines:
        return ""
    body = "\n".join(lines)
    if text.endswith("\n"):
        return body + "\n"
    return body


def text_stats(text: str, _args: dict) -> tuple[str, str]:
    lines = _lines(text)
    words = len(re.findall(r"\S+", text))
    chars = len(text)
    # ~200 wpm reading time
    minutes = max(1, round(words / 200)) if words else 0
    msg = f"{words} words · {chars} chars · {len(lines)} lines"
    if words:
        msg += f" · ~{minutes} min read"
    return text, msg


def sort_lines(text: str, args: dict) -> tuple[str, str]:
    lines = _lines(text)
    reverse = bool(args.get("reverse"))
    return _join(sorted(lines, reverse=reverse), text), f"Sorted {len(lines)} lines"


def reverse_lines(text: str, _args: dict) -> tuple[str, str]:
    lines = _lines(text)
    return _join(list(reversed(lines)), text), f"Reversed {len(lines)} lines"


def dedupe_lines(text: str, _args: dict) -> tuple[str, str]:
    lines = _lines(text)
    seen: set[str] = set()
    out: list[str] = []
    for line in lines:
        if line in seen:
            continue
        seen.add(line)
        out.append(line)
    removed = len(lines) - len(out)
    return _join(out, text), f"Removed {removed} duplicate line(s)"


def trim_lines(text: str, _args: dict) -> tuple[str, str]:
    lines = [ln.strip() for ln in _lines(text)]
    return _join(lines, text), "Trimmed line ends"


def number_lines(text: str, _args: dict) -> tuple[str, str]:
    lines = _lines(text)
    width = len(str(len(lines))) if lines else 1
    out = [f"{i:>{width}}. {ln}" for i, ln in enumerate(lines, 1)]
    return _join(out, text), f"Numbered {len(lines)} lines"


def join_lines(text: str, args: dict) -> tuple[str, str]:
    sep = args.get("sep", " ")
    if not isinstance(sep, str):
        raise OpError("sep must be a string")
    lines = _lines(text)
    return sep.join(lines), f"Joined {len(lines)} lines"


def split_lines(text: str, args: dict) -> tuple[str, str]:
    sep = args.get("sep", ",")
    if not isinstance(sep, str) or sep == "":
        raise OpError("sep must be a non-empty string")
    parts = text.split(sep)
    return "\n".join(parts) + ("\n" if text.endswith("\n") else ""), f"Split into {len(parts)} lines"


def prefix_suffix(text: str, args: dict) -> tuple[str, str]:
    prefix = args.get("prefix", "")
    suffix = args.get("suffix", "")
    if not isinstance(prefix, str) or not isinstance(suffix, str):
        raise OpError("prefix and suffix must be strings")
    remove = bool(args.get("remove"))
    lines = _lines(text)
    out: list[str] = []
    for ln in lines:
        if remove:
            s = ln
            if prefix and s.startswith(prefix):
                s = s[len(prefix) :]
            if suffix and s.endswith(suffix):
                s = s[: -len(suffix)]
            out.append(s)
        else:
            out.append(f"{prefix}{ln}{suffix}")
    action = "Removed" if remove else "Added"
    return _join(out, text), f"{action} prefix/suffix on {len(lines)} lines"


def cut_field(text: str, args: dict) -> tuple[str, str]:
    raw_n = args.get("n", args.get("field", 1))
    try:
        n = int(raw_n)
    except (TypeError, ValueError) as exc:
        raise OpError("field index n must be an integer") from exc
    if n == 0:
        raise OpError("field index n must be non-zero (1-based)")
    delim = args.get("delim", "\t")
    if not isinstance(delim, str) or delim == "":
        raise OpError("delim must be a non-empty string")
    lines = _lines(text)
    out: list[str] = []
    for ln in lines:
        parts = ln.split(delim)
        idx = n - 1 if n > 0 else len(parts) + n
        if 0 <= idx < len(parts):
            out.append(parts[idx])
        else:
            out.append("")
    return _join(out, text), f"Cut field {n}"
