"""JSON / CSV / XML / path transforms (stdlib)."""

from __future__ import annotations

import csv
import io
import json
import re
import xml.etree.ElementTree as ET
from typing import Any

from .lines import OpError


def json_pretty(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n", "JSON pretty"


def json_minify(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    return json.dumps(data, separators=(",", ":"), ensure_ascii=False), "JSON minify"


def csv_pretty(text: str, _args: dict) -> tuple[str, str]:
    reader = csv.reader(io.StringIO(text))
    rows = list(reader)
    if not rows:
        return text, "CSV empty"
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerows(rows)
    return buf.getvalue(), f"CSV {len(rows)} row(s)"


def _parse_xml(text: str) -> ET.Element:
    # Clipboard may be hostile; refuse DTD/ENTITY expansion vectors.
    upper = text[:2000].upper()
    if "<!DOCTYPE" in upper or "<!ENTITY" in upper:
        raise OpError("XML with DOCTYPE/ENTITY is not supported")
    try:
        return ET.fromstring(text)
    except ET.ParseError as exc:
        raise OpError(f"invalid XML: {exc}") from exc


def xml_pretty(text: str, _args: dict) -> tuple[str, str]:
    root = _parse_xml(text)
    ET.indent(root, space="  ")
    out = ET.tostring(root, encoding="unicode")
    return out + "\n", "XML pretty"


def csv_json(text: str, _args: dict) -> tuple[str, str]:
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        raise OpError("CSV has no header row")
    rows = list(reader)
    return json.dumps(rows, indent=2, ensure_ascii=False) + "\n", f"CSV → JSON ({len(rows)} rows)"


def json_csv(text: str, _args: dict) -> tuple[str, str]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    if not isinstance(data, list) or not data:
        raise OpError("JSON must be a non-empty array of objects")
    if not all(isinstance(row, dict) for row in data):
        raise OpError("JSON array items must be objects")
    # Preserve key order from first object, then union
    fieldnames: list[str] = []
    seen: set[str] = set()
    for row in data:
        for k in row:
            if k not in seen:
                seen.add(k)
                fieldnames.append(k)
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(data)
    return buf.getvalue(), f"JSON → CSV ({len(data)} rows)"


def _xml_to_obj(el: ET.Element) -> Any:
    children = list(el)
    if not children:
        return el.text or ""
    grouped: dict[str, Any] = {}
    for child in children:
        val = _xml_to_obj(child)
        if child.tag in grouped:
            existing = grouped[child.tag]
            if not isinstance(existing, list):
                grouped[child.tag] = [existing]
            grouped[child.tag].append(val)
        else:
            grouped[child.tag] = val
    return grouped


def xml_json(text: str, _args: dict) -> tuple[str, str]:
    root = _parse_xml(text)
    obj = {root.tag: _xml_to_obj(root)}
    return json.dumps(obj, indent=2, ensure_ascii=False) + "\n", "XML → JSON"


_PATH_TOKEN = re.compile(r"\.?([^[.\]]+)|\[(\d+)\]")


def json_path(text: str, args: dict) -> tuple[str, str]:
    path = args.get("path", args.get("p", ""))
    if not isinstance(path, str) or not path.strip():
        raise OpError("path is required (e.g. items.0.name)")
    try:
        data: Any = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OpError(f"invalid JSON: {exc.msg}") from exc
    cur: Any = data
    for m in _PATH_TOKEN.finditer(path.lstrip("$")):
        key, idx = m.group(1), m.group(2)
        try:
            if idx is not None:
                cur = cur[int(idx)]
            elif isinstance(cur, list) and key.isdigit():
                cur = cur[int(key)]
            else:
                cur = cur[key]
        except (KeyError, IndexError, TypeError) as exc:
            raise OpError(f"path not found: {path}") from exc
    if isinstance(cur, (dict, list)):
        out = json.dumps(cur, indent=2, ensure_ascii=False) + "\n"
    else:
        out = "" if cur is None else str(cur)
    return out, f"JSON path {path}"
