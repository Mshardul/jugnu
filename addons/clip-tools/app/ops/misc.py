"""Misc clipboard transforms."""

from __future__ import annotations

import re
import unicodedata

from .lines import OpError, _join, _lines


_INVISIBLE = re.compile(
    r"[\u200b\u200c\u200d\u2060\ufeff\u00a0\u202a-\u202e\u2066-\u2069]"
)


def tabs_spaces(text: str, args: dict) -> tuple[str, str]:
    direction = args.get("to", args.get("direction", "spaces"))
    width = args.get("width", 2)
    try:
        width = int(width)
    except (TypeError, ValueError) as exc:
        raise OpError("width must be an integer") from exc
    if width < 1:
        raise OpError("width must be >= 1")
    if not isinstance(direction, str):
        raise OpError("to must be a string")
    direction = direction.lower()
    if direction in ("spaces", "space"):
        return text.expandtabs(width), f"Tabs → {width} spaces"
    if direction in ("tabs", "tab"):
        # naive: replace runs of `width` spaces at line starts / general
        return text.replace(" " * width, "\t"), f"{width} spaces → tabs"
    raise OpError("to must be 'spaces' or 'tabs'")


def invisible_chars(text: str, args: dict) -> tuple[str, str]:
    mode = args.get("mode", "strip")
    if not isinstance(mode, str):
        raise OpError("mode must be a string")
    mode = mode.lower()
    if mode == "strip":
        return _INVISIBLE.sub("", text), "Stripped invisible chars"
    if mode == "show":
        def repl(m: re.Match[str]) -> str:
            cp = ord(m.group(0))
            return f"<U+{cp:04X}>"

        return _INVISIBLE.sub(repl, text), "Showed invisible chars"
    raise OpError("mode must be 'strip' or 'show'")


def markdown_table(text: str, args: dict) -> tuple[str, str]:
    direction = args.get("to", "md")
    if not isinstance(direction, str):
        raise OpError("to must be a string")
    direction = direction.lower()
    lines = [ln for ln in _lines(text) if ln.strip() != ""]
    if not lines:
        raise OpError("empty input")
    if direction in ("md", "markdown"):
        delim = "\t" if "\t" in lines[0] else ","
        rows = [ln.split(delim) for ln in lines]
        width = max(len(r) for r in rows)
        rows = [r + [""] * (width - len(r)) for r in rows]
        header = rows[0]
        body = rows[1:] if len(rows) > 1 else []
        def fmt(row: list[str]) -> str:
            return "| " + " | ".join(cell.strip() for cell in row) + " |"
        out = [fmt(header), "| " + " | ".join("---" for _ in header) + " |"]
        out.extend(fmt(r) for r in body)
        return "\n".join(out) + "\n", "TSV/CSV → Markdown table"
    if direction in ("tsv", "csv"):
        delim = "\t" if direction == "tsv" else ","
        rows = []
        for ln in lines:
            if re.match(r"^\|\s*-+", ln):
                continue
            if ln.strip().startswith("|"):
                cells = [c.strip() for c in ln.strip().strip("|").split("|")]
                rows.append(cells)
        return "\n".join(delim.join(r) for r in rows) + "\n", f"Markdown → {direction.upper()}"
    raise OpError("to must be md, tsv, or csv")


_EMAIL = re.compile(r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+")


def extract_emails(text: str, _args: dict) -> tuple[str, str]:
    found = sorted(set(_EMAIL.findall(text)))
    return "\n".join(found) + ("\n" if found else ""), f"{len(found)} email(s)"


def lorem(text: str, args: dict) -> tuple[str, str]:
    n = args.get("n", args.get("words", 50))
    try:
        n = int(n)
    except (TypeError, ValueError) as exc:
        raise OpError("n must be an integer") from exc
    if n < 1:
        raise OpError("n must be >= 1")
    words = (
        "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod "
        "tempor incididunt ut labore et dolore magna aliqua ut enim ad minim "
        "veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea "
        "commodo consequat duis aute irure dolor in reprehenderit in voluptate "
        "velit esse cillum dolore eu fugiat nulla pariatur"
    ).split()
    out = " ".join(words[i % len(words)] for i in range(n))
    return out, f"Lorem {n} words"


def regex_replace(text: str, args: dict) -> tuple[str, str]:
    pattern = args.get("pattern", args.get("re"))
    repl = args.get("repl", args.get("replacement", ""))
    if not isinstance(pattern, str) or pattern == "":
        raise OpError("pattern is required")
    if not isinstance(repl, str):
        raise OpError("repl must be a string")
    flags = 0
    if args.get("ignore_case") or args.get("i"):
        flags |= re.IGNORECASE
    try:
        rx = re.compile(pattern, flags)
    except re.error as exc:
        raise OpError(f"invalid regex: {exc}") from exc
    out, n = rx.subn(repl, text)
    return out, f"Replaced {n} match(es)"


def unicode_name(text: str, _args: dict) -> tuple[str, str]:
    if not text:
        raise OpError("clipboard is empty")
    # First grapheme-ish: first codepoint
    ch = text[0]
    name = unicodedata.name(ch, "UNKNOWN")
    out = f"U+{ord(ch):04X} {name}"
    if len(text) > 1:
        lines = [f"U+{ord(c):04X} {unicodedata.name(c, 'UNKNOWN')}" for c in text[:32]]
        if len(text) > 32:
            lines.append("…")
        out = "\n".join(lines)
    return out, "Unicode name"


def md_link(text: str, args: dict) -> tuple[str, str]:
    url = args.get("url", "")
    if not isinstance(url, str) or not url:
        # If text looks like "label | url" or "label\nurl"
        if "|" in text:
            label, url = [p.strip() for p in text.split("|", 1)]
        else:
            parts = text.strip().splitlines()
            if len(parts) >= 2:
                label, url = parts[0].strip(), parts[1].strip()
            else:
                raise OpError("need label and url (args.url or label|url)")
    else:
        label = text.strip() or url
    return f"[{label}]({url})", "Markdown link"


def clip_clear(_text: str, _args: dict) -> tuple[str, str]:
    return "", "Clipboard cleared"
