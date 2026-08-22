#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/build-registry.sh <dist-dir> <release-base-url> > registry/addons.json
#
# Packages every addons/<id> leaf, then emits registry/addons.json built from
# the actual zips (real sha256, real version) instead of hand-maintained
# entries. release-base-url is the GitHub Release download prefix, e.g.
# https://github.com/Mshardul/jugnu/releases/download/addons-v1.0.0

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <dist-dir> <release-base-url>" >&2
  exit 1
fi

dist_dir=$1
release_base_url=$2
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

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
}
