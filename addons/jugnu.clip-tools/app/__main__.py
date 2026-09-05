"""clip-tools router: stdin api:1 JSON → clipboard transform → stdout JSON."""

from __future__ import annotations

import json
import os
import sys
from typing import Any, Callable

from clipboard import ClipboardError, read_text, write_text
from ops import caseops, encode, identity, lines, misc, structured, yamlops
from ops.lines import OpError

Handler = Callable[[str, dict], tuple[str, str]]

COMMANDS: dict[str, Handler] = {
    # stats / lines
    "text-stats": lines.text_stats,
    "sort-lines": lines.sort_lines,
    "reverse-lines": lines.reverse_lines,
    "dedupe-lines": lines.dedupe_lines,
    "trim-lines": lines.trim_lines,
    "number-lines": lines.number_lines,
    "join-lines": lines.join_lines,
    "split-lines": lines.split_lines,
    "prefix-suffix": lines.prefix_suffix,
    "cut-field": lines.cut_field,
    # case
    "case": caseops.case,
    "case-lower": caseops.case_lower,
    "case-upper": caseops.case_upper,
    "case-title": caseops.case_title,
    "case-camel": caseops.case_camel,
    "case-snake": caseops.case_snake,
    "case-kebab": caseops.case_kebab,
    # structured
    "json-pretty": structured.json_pretty,
    "json-minify": structured.json_minify,
    "csv-pretty": structured.csv_pretty,
    "xml-pretty": structured.xml_pretty,
    "csv-json": structured.csv_json,
    "json-csv": structured.json_csv,
    "xml-json": structured.xml_json,
    "json-path": structured.json_path,
    "yaml-pretty": yamlops.yaml_pretty,
    "yaml-json": yamlops.yaml_json,
    "json-yaml": yamlops.json_yaml,
    # encode
    "base64-encode": encode.base64_encode,
    "base64-decode": encode.base64_decode,
    "url-encode": encode.url_encode,
    "url-decode": encode.url_decode,
    "html-escape": encode.html_escape,
    "html-unescape": encode.html_unescape,
    "jwt-decode": encode.jwt_decode,
    "hash": encode.hash_text,
    "slugify": encode.slugify,
    # identity
    "uuid": identity.uuid_gen,
    "timestamp": identity.timestamp,
    "iso-week": identity.iso_week,
    # misc
    "tabs-spaces": misc.tabs_spaces,
    "invisible-chars": misc.invisible_chars,
    "markdown-table": misc.markdown_table,
    "extract-emails": misc.extract_emails,
    "lorem": misc.lorem,
    "regex-replace": misc.regex_replace,
    "unicode-name": misc.unicode_name,
    "md-link": misc.md_link,
    "clip-clear": misc.clip_clear,
}


def _emit(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.write("\n")


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
    handler = COMMANDS.get(command)
    if handler is None:
        _emit({"ok": False, "error": f"unknown command: {command}"})
        return

    try:
        if inject and "_text" in args:
            text = args.get("_text")
            if not isinstance(text, str):
                raise OpError("_text must be a string")
            # Do not pass inject-only keys into ops
            op_args = {k: v for k, v in args.items() if k != "_text"}
        else:
            text = read_text()
            op_args = args
        new_text, message = handler(text, op_args)
        if not inject:
            write_text(new_text)
        out: dict[str, Any] = {"ok": True, "message": message}
        if inject:
            out["result"] = new_text
        _emit(out)
    except OpError as exc:
        _emit({"ok": False, "error": str(exc)})
    except ClipboardError as exc:
        _emit({"ok": False, "error": str(exc)})
    except Exception:
        # Never dump stacks to the shell user surface
        _emit({"ok": False, "error": "transform failed"})


if __name__ == "__main__":
    main()
