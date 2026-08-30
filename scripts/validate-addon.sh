#!/usr/bin/env bash
set -euo pipefail

# Kept in sync with DaemonAgents.firstPartyDaemonIDs (Swift). See plan §3.2 consistency notes.
FIRST_PARTY_DAEMON_IDS=(keep-awake clipboard-history)

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

lifecycle_tokens=$(grep -nE '^[[:space:]]*lifecycle:[[:space:]]*' "$manifest" 2>/dev/null \
  | sed -E 's/^[0-9]+:[[:space:]]*lifecycle:[[:space:]]*//; s/[[:space:]]*#.*$//' \
  | tr -d '"' | tr -d "'" || true)

has_daemon=no
while read -r token; do
  [[ -z "$token" ]] && continue
  case "$token" in
    oneshot|job) ;;
    daemon) has_daemon=yes ;;
    session) echo "session addons are not yet supported" >&2; exit 1 ;;
    *) echo "invalid lifecycle: $token" >&2; exit 1 ;;
  esac
done <<< "$lifecycle_tokens"

if [[ "$has_daemon" == "yes" ]]; then
  allowed=no
  for allow in "${FIRST_PARTY_DAEMON_IDS[@]}"; do
    [[ "$id" == "$allow" ]] && allowed=yes
  done
  [[ "$allowed" == "yes" ]] || { echo "daemon lifecycle is first-party only" >&2; exit 1; }

  awk '
    function flush() {
      if (!bad && in_cmd && is_daemon && !has_program) {
        print "daemon command missing daemon block with program:" > "/dev/stderr"
        bad = 1
      }
    }
    /^commands:/ { in_commands = 1; next }
    in_commands && /^[^[:space:]#]/ { flush(); in_commands = 0; in_cmd = 0 }
    in_commands && /^[[:space:]]+-[[:space:]]+id:/ { flush(); in_cmd = 1; is_daemon = 0; has_program = 0; next }
    in_cmd && /^[[:space:]]*lifecycle:[[:space:]]*daemon([[:space:]]|$)/ { is_daemon = 1 }
    in_cmd && /^[[:space:]]*program:[[:space:]]*[^[:space:]#]/ { has_program = 1 }
    END { flush(); exit bad }
  ' "$manifest"
fi

timeout_bad=$(grep -nE '^[[:space:]]*timeout:[[:space:]]*' "$manifest" 2>/dev/null \
  | sed -E 's/^[0-9]+:[[:space:]]*timeout:[[:space:]]*//; s/[[:space:]]*#.*$//' \
  | tr -d '"' | tr -d "'" \
  | awk '$1 + 0 > 10 { print; exit }' || true)
[[ -z "$timeout_bad" ]] || { echo "timeout must be ≤ oneshotHardCeiling (10s)" >&2; exit 1; }

entrypoint_file="$addon_dir/$entrypoint_path"
if grep -qE '(^|[[:space:]])(disown|nohup)([[:space:]]|$)|&[[:space:]]*$' "$entrypoint_file"; then
  echo "warning: $id entrypoint uses disown/nohup/trailing &; background work belongs in a daemon or the clock helper" >&2
fi

printf 'valid addon: %s %s (api %s)\n' "$id" "$version" "$api"
