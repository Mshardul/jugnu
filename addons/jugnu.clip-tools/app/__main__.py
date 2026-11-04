"""clip-tools router: stdin api:1 JSON → clipboard transform → stdout JSON."""

from __future__ import annotations

import importlib
import json
import os
import sys
from collections.abc import Callable
from typing import Any

from ops.lines import OpError

Handler = Callable[[str, dict], tuple[str, str]]

# "module.function" strings, resolved on demand so one invocation imports only the op module
# it needs (startup latency is on the Convert speed budget).
COMMANDS: dict[str, str] = {
    # stats / lines
    "text-stats": "lines.text_stats",
    "sort-lines": "lines.sort_lines",
    "reverse-lines": "lines.reverse_lines",
    "dedupe-lines": "lines.dedupe_lines",
    "trim-lines": "lines.trim_lines",
    "number-lines": "lines.number_lines",
    "join-lines": "lines.join_lines",
    "split-lines": "lines.split_lines",
    "prefix-suffix": "lines.prefix_suffix",
    "cut-field": "lines.cut_field",
    # case
    "case": "caseops.case",
    "case-lower": "caseops.case_lower",
    "case-upper": "caseops.case_upper",
    "case-title": "caseops.case_title",
    "case-camel": "caseops.case_camel",
    "case-snake": "caseops.case_snake",
    "case-kebab": "caseops.case_kebab",
    # structured
    "json-pretty": "structured.json_pretty",
    "json-minify": "structured.json_minify",
    "csv-pretty": "structured.csv_pretty",
    "xml-pretty": "structured.xml_pretty",
    "csv-json": "structured.csv_json",
    "json-csv": "structured.json_csv",
    "xml-json": "structured.xml_json",
    "json-path": "structured.json_path",
    "yaml-pretty": "yamlops.yaml_pretty",
    "yaml-json": "yamlops.yaml_json",
    "json-yaml": "yamlops.json_yaml",
    # convert-only (Convert addon)
    "json-tsv": "convertops.json_tsv",
    "tsv-json": "convertops.tsv_json",
    "csv-tsv": "convertops.csv_tsv",
    "tsv-csv": "convertops.tsv_csv",
    "json-xml": "convertops.json_xml",
    "csv-markdown-table": "convertops.csv_markdown_table",
    "json-markdown-table": "convertops.json_markdown_table",
    "markdown-table-csv": "convertops.markdown_table_csv",
    "markdown-table-json": "convertops.markdown_table_json",
    "markdown-html": "convertops.markdown_html",
    "html-markdown": "convertops.html_markdown",
    "html-plain": "convertops.html_plain",
    # encode
    "base64-encode": "encode.base64_encode",
    "base64-decode": "encode.base64_decode",
    "url-encode": "encode.url_encode",
    "url-decode": "encode.url_decode",
    "html-escape": "encode.html_escape",
    "html-unescape": "encode.html_unescape",
    "jwt-decode": "encode.jwt_decode",
    "hash": "encode.hash_text",
    "slugify": "encode.slugify",
    # identity
    "uuid": "identity.uuid_gen",
    "timestamp": "identity.timestamp",
    "iso-week": "identity.iso_week",
    # misc
    "tabs-spaces": "misc.tabs_spaces",
    "invisible-chars": "misc.invisible_chars",
    "markdown-table": "misc.markdown_table",
    "extract-emails": "misc.extract_emails",
    "lorem": "misc.lorem",
    "regex-replace": "misc.regex_replace",
    "unicode-name": "misc.unicode_name",
    "md-link": "misc.md_link",
    "clip-clear": "misc.clip_clear",
    "paste-plain": "misc.paste_plain",
}

# Commands the shell Convert view may call (`op: convert`): command id → (from, to).
# Mirrors addon.yaml `converters:`. Text in, text out, no clipboard; the handlers are
# the same ones the palette commands use.
CONVERT_EDGES: dict[str, tuple[str, str]] = {
    "json-csv": ("json", "csv"),
    "csv-json": ("csv", "json"),
    "xml-json": ("xml", "json"),
    "yaml-json": ("yaml", "json"),
    "json-yaml": ("json", "yaml"),
    "json-tsv": ("json", "tsv"),
    "tsv-json": ("tsv", "json"),
    "csv-tsv": ("csv", "tsv"),
    "tsv-csv": ("tsv", "csv"),
    "json-xml": ("json", "xml"),
    "csv-markdown-table": ("csv", "markdown-table"),
    "json-markdown-table": ("json", "markdown-table"),
    "markdown-table-csv": ("markdown-table", "csv"),
    "markdown-table-json": ("markdown-table", "json"),
    "markdown-html": ("markdown", "html"),
    "html-markdown": ("html", "markdown"),
    "html-plain": ("html", "plain"),
}

# Commands whose input is the raw pasteboard read (RTF/HTML source), not the
# plain-text flavor every other op assumes — see clipboard.read_as_plain_text.
RAW_READ_COMMANDS = {"paste-plain"}

# File-mode conversions read the whole file; keep them to a size a live UI can wait for.
MAX_CONVERT_FILE_BYTES = 10 * 1024 * 1024


def _handler(command: str) -> Handler | None:
    target = COMMANDS.get(command)
    if target is None:
        return None
    module, _, name = target.partition(".")
    return getattr(importlib.import_module(f"ops.{module}"), name)


def _emit(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.write("\n")


def _convert(req: dict) -> None:
    command = req.get("command")
    edge = CONVERT_EDGES.get(command) if isinstance(command, str) else None
    if edge is None:
        _emit({"ok": False, "error": f"unknown converter: {command}"})
        return
    if (req.get("from"), req.get("to")) != edge:
        _emit({"ok": False, "error": f"{command} converts {edge[0]} to {edge[1]}"})
        return
    if "path" in req:
        _convert_file(command, req)
        return
    text = req.get("text")
    if not isinstance(text, str):
        _emit({"ok": False, "error": "text must be a string"})
        return
    try:
        new_text, _message = _handler(command)(text, {})
        _emit({"ok": True, "text": new_text})
    except OpError as exc:
        _emit({"ok": False, "error": str(exc)})
    except Exception:
        _emit({"ok": False, "error": "conversion failed"})


def _convert_file(command: str, req: dict) -> None:
    src, dst = req.get("path"), req.get("out")
    if not isinstance(src, str) or not isinstance(dst, str) or not src or not dst:
        _emit({"ok": False, "error": "path and out must be strings"})
        return
    try:
        if os.path.getsize(src) > MAX_CONVERT_FILE_BYTES:
            _emit({"ok": False, "error": "file is too large to convert"})
            return
        with open(src, encoding="utf-8") as handle:
            text = handle.read()
    except UnicodeDecodeError:
        _emit({"ok": False, "error": "file is not UTF-8 text"})
        return
    except OSError:
        _emit({"ok": False, "error": "could not read the file"})
        return
    try:
        new_text, _message = _handler(command)(text, {})
    except OpError as exc:
        _emit({"ok": False, "error": str(exc)})
        return
    except Exception:
        _emit({"ok": False, "error": "conversion failed"})
        return
    try:
        with open(dst, "w", encoding="utf-8") as handle:
            handle.write(new_text)
    except OSError:
        _emit({"ok": False, "error": "could not write the converted file"})
        return
    _emit({"ok": True, "path": dst})


def main() -> None:
    raw = sys.stdin.read()
    try:
        req = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        _emit({"ok": False, "error": "invalid request JSON"})
        return

    if req.get("api") != 1:
        _emit({"ok": False, "error": "unsupported api"})
        return
    if req.get("op") == "convert":
        _convert(req)
        return
    if req.get("op") != "run":
        _emit({"ok": False, "error": "unsupported op"})
        return

    command = req.get("command")
    if not isinstance(command, str) or not command:
        _emit({"ok": False, "error": "missing command"})
        return

    args = req.get("args") or {}
    if not isinstance(args, dict):
        _emit({"ok": False, "error": "args must be an object"})
        return

    inject = os.environ.get("JUGNU_CLIP_TOOLS_INJECT") == "1"
    handler = _handler(command)
    if handler is None:
        _emit({"ok": False, "error": f"unknown command: {command}"})
        return

    import clipboard  # lazy: pulls in subprocess, unused on the convert path

    try:
        if inject and "_text" in args:
            text = args.get("_text")
            if not isinstance(text, str):
                raise OpError("_text must be a string")
            # Do not pass inject-only keys into ops
            op_args = {k: v for k, v in args.items() if k != "_text"}
        else:
            text = clipboard.read_as_plain_text() if command in RAW_READ_COMMANDS else clipboard.read_text()
            op_args = args
        new_text, message = handler(text, op_args)
        if not inject:
            clipboard.write_text(new_text)
        out: dict[str, Any] = {"ok": True, "message": message}
        if inject:
            out["result"] = new_text
        _emit(out)
    except OpError as exc:
        _emit({"ok": False, "error": str(exc)})
    except clipboard.ClipboardError as exc:
        _emit({"ok": False, "error": str(exc)})
    except Exception:
        # Never dump stacks to the shell user surface
        _emit({"ok": False, "error": "transform failed"})


if __name__ == "__main__":
    main()
