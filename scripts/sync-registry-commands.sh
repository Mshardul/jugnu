#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/sync-registry-commands.sh [--check]
#
# Regenerates the `commands` array on every registry/addons.json entry from
# the matching addons/<id>/addon.yaml. Only ever touches `commands` — never
# category/tags/description/summary/version/url/sha256 (those stay
# hand-authored or are owned by build-registry.sh).

check_mode="False"
if [[ "${1:-}" == "--check" ]]; then
  check_mode="True"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

python3 - "$repo_root/registry/addons.json" "$repo_root" "$check_mode" <<'PYEOF'
import json, subprocess, sys

registry_file, repo_root, check_mode = sys.argv[1], sys.argv[2], sys.argv[3] == "True"

with open(registry_file) as f:
    original_text = f.read()
entries = json.loads(original_text)

for entry in entries:
    addon_id = entry["id"]
    manifest = f"{repo_root}/addons/{addon_id}/addon.yaml"
    try:
        raw = subprocess.check_output(
            [f"{repo_root}/scripts/_extract_commands.sh", manifest], text=True
        )
        entry["commands"] = json.loads(raw)
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        entry["commands"] = []

new_text = json.dumps(entries, indent=2) + "\n"

if check_mode:
    if new_text != original_text:
        sys.stderr.write("registry/addons.json commands are stale — run scripts/sync-registry-commands.sh\n")
        sys.exit(1)
    sys.exit(0)

with open(registry_file, "w") as f:
    f.write(new_text)
PYEOF
