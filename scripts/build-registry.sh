#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/build-registry.sh <dist-dir> <release-base-url>
#
# Packages every addons/<id> leaf, then writes registry/addons.json from the
# actual zips (real sha256, real version). Hand-authored catalog fields
# (category, subcategory, tags, description, commands) are preserved from the
# existing registry file. Do not redirect stdout onto registry/addons.json —
# the shell would truncate it before this script can read those fields.
#
# release-base-url is the GitHub Release download prefix, e.g.
# https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <dist-dir> <release-base-url>" >&2
  exit 1
fi

dist_dir=$1
release_base_url=$2
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
registry_file="$repo_root/registry/addons.json"

if [[ ! -s "$registry_file" ]]; then
  echo "$0: $registry_file is missing or empty; cannot preserve category/tags/description/commands" >&2
  echo "Do not redirect stdout onto registry/addons.json." >&2
  exit 1
fi

mkdir -p "$dist_dir"
dist_dir=$(cd "$dist_dir" && pwd)

manifest_value() {
  local manifest="$1" key="$2"
  sed -n "s/^${key}:[[:space:]]*//p" "$manifest" | head -1 | sed 's/[[:space:]]*#.*$//' | tr -d '"' | tr -d "'"
}

first_command_title() {
  local manifest="$1"
  awk '
    /^commands:/ { in_commands=1; next }
    in_commands && /^  - id:/ { found_item=1 }
    in_commands && found_item && /^    title:/ {
      sub(/^    title:[[:space:]]*/, "")
      print
      exit
    }
    in_commands && /^[a-z]/ && !/^  /  { exit }
  ' "$manifest" | tr -d '"' | tr -d "'"
}

entries=()

for addon_dir in "$repo_root"/addons/*/; do
  addon_dir=${addon_dir%/}
  manifest="$addon_dir/addon.yaml"
  [[ -f "$manifest" ]] || continue

  id=$(manifest_value "$manifest" id)
  [[ "$id" == ui-demo-* ]] && continue

  name=$(manifest_value "$manifest" name)
  version=$(manifest_value "$manifest" version)
  api=$(manifest_value "$manifest" api)
  summary=$(first_command_title "$manifest")

  sha256=$("$script_dir/package-addon.sh" "$addon_dir" "$dist_dir" 2>/dev/null)
  zip_name="${id}-${version}.zip"

  entry=$(cat <<JSON
  {
    "id": "${id}",
    "name": "${name}",
    "version": "${version}",
    "api": ${api},
    "url": "${release_base_url}/${zip_name}",
    "sha256": "${sha256}",
    "summary": "${summary}"
  }
JSON
)
  entries+=("$entry")
done

new_json=$(mktemp)
trap 'rm -f "$new_json"' EXIT
{
  echo "["
  for i in "${!entries[@]}"; do
    if [[ "$i" -lt $(( ${#entries[@]} - 1 )) ]]; then
      echo "${entries[$i]},"
    else
      echo "${entries[$i]}"
    fi
  done
  echo "]"
} > "$new_json"

python3 - "$registry_file" "$new_json" <<'PYEOF'
import json, sys

registry_file, new_file = sys.argv[1], sys.argv[2]
new_entries = json.loads(open(new_file).read())
existing = json.loads(open(registry_file).read())
by_id = {entry["id"]: entry for entry in existing}
preserve = ("category", "subcategory", "tags", "description", "commands")
missing = []
for entry in new_entries:
    old = by_id.get(entry["id"], {})
    for key in preserve:
        if key in old:
            entry[key] = old[key]
    if not entry.get("category"):
        missing.append(entry["id"])
if missing:
    sys.stderr.write(
        "build-registry: missing category for: " + ", ".join(missing) + "\n"
        "Add category (and optional subcategory/tags/description) in "
        "registry/addons.json before rebuilding.\n"
    )
    sys.exit(1)
with open(registry_file, "w") as handle:
    json.dump(new_entries, handle, indent=2)
    handle.write("\n")
PYEOF

