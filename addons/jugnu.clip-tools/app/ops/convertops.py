"""Format-to-format conversions for the Convert addon (stdlib only).

Every handler is `(text, args) -> (text, message)` like the other ops, so the palette commands and
`op: convert` share one implementation.
"""

from __future__ import annotations

import csv
import io
import json
import re
from html import escape as html_escape
from html.parser import HTMLParser
from typing import Any
from xml.etree import ElementTree as ET  # nosemgrep

from .lines import OpError

# ---------------------------------------------------------------- tabular


def _load_json_rows(text: str) -> tuple[list[str], list[dict]]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    if not isinstance(data, list) or not data:
        raise OpError("JSON must be a non-empty array of objects")
    if not all(isinstance(row, dict) for row in data):
        raise OpError("JSON array items must be objects")
    fields: list[str] = []
    for row in data:
        for key in row:
            if key not in fields:
                fields.append(key)
    return fields, data


def _read_rows(text: str, delimiter: str) -> list[list[str]]:
    rows = [r for r in csv.reader(io.StringIO(text), delimiter=delimiter) if r]
    if not rows:
        raise OpError("no rows found")
    return rows


def _write_rows(rows: list[list[Any]], delimiter: str) -> str:
    buf = io.StringIO()
    csv.writer(buf, delimiter=delimiter, lineterminator="\n").writerows(rows)
    return buf.getvalue()


def _rows_to_json(rows: list[list[str]]) -> str:
    header, body = rows[0], rows[1:]
    records = [
        dict(zip(header, row + [""] * (len(header) - len(row)), strict=False)) for row in body
    ]
    return json.dumps(records, indent=2, ensure_ascii=False) + "\n"


def _json_to_delimited(text: str, delimiter: str) -> str:
    fields, data = _load_json_rows(text)
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=fields, delimiter=delimiter, lineterminator="\n")
    writer.writeheader()
    writer.writerows(data)
    return buf.getvalue()


def json_tsv(text: str, _args: dict) -> tuple[str, str]:
    return _json_to_delimited(text, "\t"), "JSON → TSV"


def tsv_json(text: str, _args: dict) -> tuple[str, str]:
    return _rows_to_json(_read_rows(text, "\t")), "TSV → JSON"


def csv_tsv(text: str, _args: dict) -> tuple[str, str]:
    return _write_rows(_read_rows(text, ","), "\t"), "CSV → TSV"


def tsv_csv(text: str, _args: dict) -> tuple[str, str]:
    return _write_rows(_read_rows(text, "\t"), ","), "TSV → CSV"


# ---------------------------------------------------------------- markdown table


def _md_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def _md_table(rows: list[list[Any]]) -> str:
    width = max(len(r) for r in rows)
    padded = [[_md_cell(c) for c in r] + [""] * (width - len(r)) for r in rows]
    lines = [
        "| " + " | ".join(padded[0]) + " |",
        "| " + " | ".join("---" for _ in padded[0]) + " |",
    ]
    lines.extend("| " + " | ".join(r) + " |" for r in padded[1:])
    return "\n".join(lines) + "\n"


def csv_markdown_table(text: str, _args: dict) -> tuple[str, str]:
    return _md_table(_read_rows(text, ",")), "CSV → Markdown table"


def json_markdown_table(text: str, _args: dict) -> tuple[str, str]:
    fields, data = _load_json_rows(text)
    rows: list[list[Any]] = [fields] + [[row.get(f, "") for f in fields] for row in data]
    return _md_table(rows), "JSON → Markdown table"


_MD_SEPARATOR = re.compile(r"^\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?$")
_UNESCAPED_PIPE = re.compile(r"(?<!\\)\|")


def _parse_md_table(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or "|" not in stripped or _MD_SEPARATOR.match(stripped):
            continue
        if stripped.startswith("|"):
            stripped = stripped[1:]
        if stripped.endswith("|") and not stripped.endswith("\\|"):
            stripped = stripped[:-1]
        rows.append([c.strip().replace("\\|", "|") for c in _UNESCAPED_PIPE.split(stripped)])
    if not rows:
        raise OpError("no Markdown table found")
    return rows


def markdown_table_csv(text: str, _args: dict) -> tuple[str, str]:
    return _write_rows(_parse_md_table(text), ","), "Markdown table → CSV"


def markdown_table_json(text: str, _args: dict) -> tuple[str, str]:
    return _rows_to_json(_parse_md_table(text)), "Markdown table → JSON"


# ---------------------------------------------------------------- JSON -> XML

_XML_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]*$")


def _xml_name(name: Any) -> str:
    if not isinstance(name, str) or not _XML_NAME.match(name) or name.lower().startswith("xml"):
        raise OpError(f"can't use {name!r} as an XML element name")
    return name


def _fill(parent: ET.Element, value: Any) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            _add(parent, _xml_name(key), child)
    elif value is None:
        parent.text = ""
    elif isinstance(value, bool):
        parent.text = "true" if value else "false"
    else:
        parent.text = str(value)


def _add(parent: ET.Element, name: str, value: Any) -> None:
    if isinstance(value, list):
        for item in value:
            _add(parent, name, item)
        return
    _fill(ET.SubElement(parent, name), value)


def json_xml(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    if (
        isinstance(data, dict)
        and len(data) == 1
        and not isinstance(next(iter(data.values())), list)
    ):
        name, body = next(iter(data.items()))
        root = ET.Element(_xml_name(name))
        _fill(root, body)
    else:
        root = ET.Element("root")
        _fill(root, {"item": data} if not isinstance(data, dict) else data)
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="unicode") + "\n", "JSON → XML"


# ---------------------------------------------------------------- Markdown -> HTML

_SAFE_URL = re.compile(r"^(https?://|mailto:|/|#|\./|\.\./)", re.IGNORECASE)


def _inline(text: str) -> str:
    out = html_escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)

    def link(match: re.Match) -> str:
        label, url = match.group(1), match.group(2).strip()
        if not _SAFE_URL.match(url) and ":" in url.split("/")[0]:
            return label  # drop javascript:, data:, etc.
        return f'<a href="{html_escape(url, quote=True)}">{label}</a>'

    out = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, out)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)", r"<em>\1</em>", out)
    return out


def markdown_html(text: str, _args: dict) -> tuple[str, str]:
    blocks: list[str] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
        elif line.startswith("```"):
            i += 1
            code: list[str] = []
            while i < len(lines) and not lines[i].startswith("```"):
                code.append(lines[i])
                i += 1
            i += 1
            blocks.append(
                "<pre><code>" + html_escape("\n".join(code), quote=False) + "</code></pre>"
            )
        elif m := re.match(r"^(#{1,6})\s+(.*)$", line):
            level = len(m.group(1))
            blocks.append(f"<h{level}>{_inline(m.group(2).strip())}</h{level}>")
            i += 1
        elif re.match(r"^(-{3,}|\*{3,}|_{3,})\s*$", line):
            blocks.append("<hr>")
            i += 1
        elif line.startswith(">"):
            quote: list[str] = []
            while i < len(lines) and lines[i].startswith(">"):
                quote.append(lines[i].lstrip(">").strip())
                i += 1
            blocks.append("<blockquote>" + _inline(" ".join(quote)) + "</blockquote>")
        elif re.match(r"^\s*([-*+]|\d+\.)\s+", line):
            ordered = bool(re.match(r"^\s*\d+\.\s+", line))
            marker = r"^\s*\d+\.\s+" if ordered else r"^\s*[-*+]\s+"
            items: list[str] = []
            while i < len(lines) and re.match(marker, lines[i]):
                items.append("<li>" + _inline(re.sub(marker, "", lines[i])) + "</li>")
                i += 1
            tag = "ol" if ordered else "ul"
            blocks.append(f"<{tag}>\n" + "\n".join(items) + f"\n</{tag}>")
        else:
            para: list[str] = []
            while (
                i < len(lines)
                and lines[i].strip()
                and not re.match(r"^(#{1,6}\s|```|>|\s*([-*+]|\d+\.)\s)", lines[i])
            ):
                para.append(lines[i].strip())
                i += 1
            blocks.append("<p>" + _inline(" ".join(para)) + "</p>")
    if not blocks:
        raise OpError("empty input")
    return "\n".join(blocks) + "\n", "Markdown → HTML"


# ---------------------------------------------------------------- HTML -> Markdown / plain

_BLOCK_TAGS = {
    "p",
    "div",
    "section",
    "article",
    "header",
    "footer",
    "table",
    "tr",
    "ul",
    "ol",
    "li",
    "blockquote",
}
_SKIP_TAGS = {"script", "style", "head", "title", "template"}


class _HTMLText(HTMLParser):
    def __init__(self, markdown: bool) -> None:
        super().__init__(convert_charrefs=True)
        self.md = markdown
        self.out: list[str] = []
        self.skip = 0
        self.lists: list[list[int]] = []
        self.href: list[str | None] = []
        self.in_pre = False

    def _newlines(self, count: int) -> None:
        text = "".join(self.out)
        have = len(text) - len(text.rstrip("\n"))
        if text and have < count:
            self.out.append("\n" * (count - have))

    def handle_starttag(self, tag: str, attrs: list) -> None:
        if tag in _SKIP_TAGS:
            self.skip += 1
            return
        if self.skip:
            return
        attr = dict(attrs)
        if tag in ("ul", "ol"):
            self.lists.append([0 if tag == "ul" else 1])
            self._newlines(1)
        elif tag == "li":
            self._newlines(1)
            depth = "  " * (len(self.lists) - 1) if self.md else ""
            top = self.lists[-1] if self.lists else [0]
            bullet = "- " if top[0] == 0 else f"{top[0]}. "
            top[0] += 1 if top[0] else 0
            self.out.append(depth + (bullet if self.md else "- "))
        elif tag in _BLOCK_TAGS or tag == "br":
            self._newlines(1 if tag in ("br", "tr") else 2)
        elif re.fullmatch(r"h[1-6]", tag):
            self._newlines(2)
            if self.md:
                self.out.append("#" * int(tag[1]) + " ")
        elif tag == "hr":
            self._newlines(2)
            self.out.append("---" if self.md else "")
            self._newlines(2)
        elif tag == "pre":
            self.in_pre = True
            self._newlines(2)
            if self.md:
                self.out.append("```\n")
        elif self.md and tag in ("strong", "b"):
            self.out.append("**")
        elif self.md and tag in ("em", "i"):
            self.out.append("*")
        elif self.md and tag == "code" and not self.in_pre:
            self.out.append("`")
        elif self.md and tag == "a":
            self.href.append(attr.get("href"))
            self.out.append("[")

    def handle_endtag(self, tag: str) -> None:
        if tag in _SKIP_TAGS:
            self.skip = max(0, self.skip - 1)
            return
        if self.skip:
            return
        if tag in ("ul", "ol"):
            if self.lists:
                self.lists.pop()
            self._newlines(2 if not self.lists else 1)
        elif tag in _BLOCK_TAGS or re.fullmatch(r"h[1-6]", tag):
            self._newlines(2)
        elif tag == "pre":
            self.in_pre = False
            if self.md:
                self._newlines(1)
                self.out.append("```")
            self._newlines(2)
        elif self.md and tag in ("strong", "b"):
            self.out.append("**")
        elif self.md and tag in ("em", "i"):
            self.out.append("*")
        elif self.md and tag == "code" and not self.in_pre:
            self.out.append("`")
        elif self.md and tag == "a":
            href = self.href.pop() if self.href else None
            self.out.append(f"]({href})" if href and _SAFE_URL.match(href) else "]")

    def handle_data(self, data: str) -> None:
        if self.skip:
            return
        if not self.in_pre:
            data = re.sub(r"\s+", " ", data)
            if "".join(self.out).endswith("\n"):
                data = data.lstrip()
        self.out.append(data)


def _html_text(text: str, markdown: bool) -> str:
    if not text.strip():
        raise OpError("empty input")
    parser = _HTMLText(markdown)
    parser.feed(text)
    parser.close()
    result = re.sub(r"\n{3,}", "\n\n", "".join(parser.out)).strip()
    return result + "\n"


def html_markdown(text: str, _args: dict) -> tuple[str, str]:
    return _html_text(text, True), "HTML → Markdown"


def html_plain(text: str, _args: dict) -> tuple[str, str]:
    return _html_text(text, False), "HTML → plain text"
