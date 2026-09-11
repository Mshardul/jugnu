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

# Prints a JSON array of permission strings from addon.yaml (or []).
manifest_permissions_json() {
  local manifest="$1"
  python3 - "$manifest" <<'PY'
import json, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
perms = []
in_p = False
for line in text.splitlines():
    if line.startswith("permissions:"):
        in_p = True
        rest = line[len("permissions:"):].strip()
        if rest.startswith("[") and rest.endswith("]"):
            inner = rest[1:-1].strip()
            if inner:
                for part in inner.split(","):
                    tok = part.strip().strip("\"'")
                    if tok:
                        perms.append(tok)
            in_p = False
        continue
    if in_p:
        if line and not line[0].isspace() and not line.startswith("-"):
            break
        s = line.strip()
        if s.startswith("-"):
            tok = s[1:].strip().strip("\"'").split("#", 1)[0].strip()
            if tok:
                perms.append(tok)
print(json.dumps(perms))
PY
}

entries=()

for addon_dir in "$repo_root"/addons/*/; do
  addon_dir=${addon_dir%/}
  manifest="$addon_dir/addon.yaml"
  [[ -f "$manifest" ]] || continue

  id=$(manifest_value "$manifest" id)
  # Demos are not catalog products. window-layouts is shipped in-tree but not
  # on the public registry yet (ticket 0046: zip/sha on a later addons release).
  case "$id" in
    ui-demo-*|*.ui-demo-*|window-layouts|*.window-layouts) continue ;;
  esac

  name=$(manifest_value "$manifest" name)
  version=$(manifest_value "$manifest" version)
  api=$(manifest_value "$manifest" api)
  summary=$(first_command_title "$manifest")
  permissions_json=$(manifest_permissions_json "$manifest")
  primary=$(manifest_value "$manifest" primary)

  sha256=$("$script_dir/package-addon.sh" "$addon_dir" "$dist_dir" 2>/dev/null)
  zip_name="${id}-${version}.zip"

  primary_json="null"
  [[ -n "$primary" ]] && primary_json="\"${primary}\""

  entry=$(cat <<JSON
  {
    "id": "${id}",
    "name": "${name}",
    "version": "${version}",
    "api": ${api},
    "url": "${release_base_url}/${zip_name}",
    "sha256": "${sha256}",
    "summary": "${summary}",
    "permissions": ${permissions_json},
    "primary": ${primary_json}
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
    # permissions and primary always come from the packaged manifest (already on entry).
    if "permissions" not in entry:
        entry["permissions"] = []
    if entry.get("primary") is None:
        entry.pop("primary", None)
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

