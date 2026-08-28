#!/usr/bin/env python3
"""Pull screenshot attachments out of an .xcresult bundle into a flat folder.

Usage: extract-screenshots.py <result.xcresult> <out_dir>

Attachment names are like "03-catalog" (set in the test); files land as
<out_dir>/03-catalog.png in that order.
"""
import json
import subprocess
import sys
from pathlib import Path


def xcresulttool(*args):
    return subprocess.run(
        ["xcrun", "xcresulttool", *args],
        capture_output=True, text=True, check=True,
    ).stdout


def get_json(bundle, ref=None):
    args = ["get", "--format", "json", "--path", bundle]
    if ref:
        args += ["--id", ref]
    return json.loads(xcresulttool(*args))


def walk(node, found):
    """Recursively collect (name, payloadRef) for image attachments."""
    if isinstance(node, dict):
        if node.get("_type", {}).get("_name") == "ActionTestAttachment":
            name = node.get("name", {}).get("_value", "attachment")
            ref = node.get("payloadRef", {}).get("id", {}).get("_value")
            uti = node.get("uniformTypeIdentifier", {}).get("_value", "")
            if ref and ("image" in uti or "png" in uti):
                found.append((name, ref))
        for v in node.values():
            walk(v, found)
    elif isinstance(node, list):
        for v in node:
            walk(v, found)


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    bundle, out_dir = sys.argv[1], Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)

    root = get_json(bundle)

    # Find the test action result, then its tests tree, chasing summaryRefs.
    refs = []

    def collect_refs(node):
        if isinstance(node, dict):
            if node.get("_type", {}).get("_name", "").endswith("Reference") and "id" in node:
                pass
            for k, v in node.items():
                if k in ("summaryRef", "testsRef") and isinstance(v, dict):
                    rid = v.get("id", {}).get("_value")
                    if rid:
                        refs.append(rid)
                collect_refs(v)
        elif isinstance(node, list):
            for v in node:
                collect_refs(v)

    collect_refs(root)

    found = []
    seen = set()
    to_visit = list(refs)
    while to_visit:
        ref = to_visit.pop()
        if ref in seen:
            continue
        seen.add(ref)
        try:
            sub = get_json(bundle, ref)
        except subprocess.CalledProcessError:
            continue
        walk(sub, found)
        # queue any nested refs
        nested = []
        collect_nested(sub, nested)
        to_visit.extend(r for r in nested if r not in seen)

    # de-dupe by (name, ref)
    uniq = []
    key_seen = set()
    for name, ref in found:
        if (name, ref) in key_seen:
            continue
        key_seen.add((name, ref))
        uniq.append((name, ref))

    if not uniq:
        print("No image attachments found in result bundle.", file=sys.stderr)
        return

    for name, ref in sorted(uniq, key=lambda t: t[0]):
        safe = name if name.endswith(".png") else name + ".png"
        dest = out_dir / safe
        data = subprocess.run(
            ["xcrun", "xcresulttool", "export", "--type", "file",
             "--path", bundle, "--id", ref, "--output-path", str(dest)],
            capture_output=True, check=False,
        )
        if dest.exists():
            print(f"  {safe}")
        else:
            print(f"  (failed) {safe}: {data.stderr.decode()[:200]}", file=sys.stderr)


def collect_nested(node, out):
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ("summaryRef", "testsRef", "subtests", "payloadRef") and isinstance(v, dict):
                rid = v.get("id", {}).get("_value")
                if rid:
                    out.append(rid)
            collect_nested(v, out)
    elif isinstance(node, list):
        for v in node:
            collect_nested(v, out)


if __name__ == "__main__":
    main()
