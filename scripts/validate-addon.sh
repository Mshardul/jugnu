#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <addon-dir>" >&2
  exit 1
fi

addon_dir=$(cd "$1" && pwd)
manifest="$addon_dir/addon.yaml"
if [[ ! -f "$manifest" ]]; then
  echo "missing addon.yaml in $addon_dir" >&2
  exit 1
fi

value() {
  sed -n "s/^$1:[[:space:]]*//p" "$manifest" | head -1 | sed 's/[[:space:]]*#.*$//' | tr -d '"' | tr -d "'"
}

id=$(value id)
version=$(value version)
api=$(value api)
entrypoint_kind=$(sed -n 's/^  kind:[[:space:]]*//p' "$manifest" | head -1 | tr -d '"' | tr -d "'")
entrypoint_path=$(sed -n 's/^  path:[[:space:]]*//p' "$manifest" | head -1 | tr -d '"' | tr -d "'")

[[ "$id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid addon id: $id" >&2; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid addon version: $version" >&2; exit 1; }
[[ "$api" == "1" ]] || { echo "unsupported addon api: $api" >&2; exit 1; }
[[ "$entrypoint_kind" == "exec" || "$entrypoint_kind" == "jxa" || "$entrypoint_kind" == "osascript" ]] || {
  echo "invalid entrypoint kind: $entrypoint_kind" >&2
  exit 1
}
[[ -n "$entrypoint_path" && "$entrypoint_path" != /* && "$entrypoint_path" != *../* && "$entrypoint_path" != ../* ]] || {
  echo "entrypoint path must be relative and cannot traverse parents" >&2
  exit 1
}
[[ -f "$addon_dir/$entrypoint_path" ]] || { echo "missing entrypoint: $entrypoint_path" >&2; exit 1; }
grep -q '^commands:' "$manifest" || { echo "missing commands in addon.yaml" >&2; exit 1; }
grep -q '^cleanup:' "$manifest" || { echo "missing cleanup in addon.yaml" >&2; exit 1; }

printf 'valid addon: %s %s (api %s)\n' "$id" "$version" "$api"
