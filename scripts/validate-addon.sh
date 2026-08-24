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

if grep -q '^helpers:' "$manifest"; then
  awk '
    /^helpers:/ { in_h = 1; next }
    in_h && /^[^[:space:]-]/ { in_h = 0 }
    in_h && $1 == "id:" {
      id = $2
      gsub(/["'\'']/, "", id)
      if (id !~ /^[a-z0-9][a-z0-9-]*$/) { print "invalid helper id: " id > "/dev/stderr"; exit 1 }
    }
    in_h && $1 == "version:" {
      ver = $2
      gsub(/["'\'']/, "", ver)
      if (ver !~ /^[0-9]+\.[0-9]+\.[0-9]+$/) { print "invalid helper version: " ver > "/dev/stderr"; exit 1 }
    }
  ' "$manifest"
fi

if grep -E '^[[:space:]]*(width|height|percent)[[:space:]]*:' "$manifest" >/dev/null; then
  echo "addon.yaml must not declare width, height, or percent; use view_types" >&2
  exit 1
fi

is_known_view() {
  case "$1" in
    seek|palette|ask|fields|rows|grid|board|spread|canvas|rail) return 0 ;;
    *) return 1 ;;
  esac
}

extract_view_tokens() {
  awk '
    $1 == "view_types:" {
      line = $0
      sub(/^view_types:[[:space:]]*/, "", line)
      gsub(/[][,]/, " ", line)
      n = split(line, parts, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (parts[i] != "") print parts[i]
      next
    }
    /^[[:space:]]+-[[:space:]]+id:/ { in_cmd = 1 }
    in_cmd && $1 == "view:" {
      print $2
      in_cmd = 0
    }
  ' "$manifest"
}

while read -r token; do
  [[ -z "$token" ]] && continue
  token=${token//\"/}
  token=${token//\'/}
  is_known_view "$token" || { echo "unknown view type: $token" >&2; exit 1; }
done < <(extract_view_tokens)

printf 'valid addon: %s %s (api %s)\n' "$id" "$version" "$api"
