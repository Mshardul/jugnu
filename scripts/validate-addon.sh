#!/usr/bin/env bash
set -euo pipefail

# Kept in sync with DaemonAgents.firstPartyDaemonIDs (Swift). See plan §3.2 consistency notes.
FIRST_PARTY_DAEMON_IDS=(jugnu.keep-awake jugnu.clipboard-history)

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

[[ "$id" =~ ^[a-z0-9]+\.[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid addon id (want publisher.job): $id" >&2; exit 1; }
dir_base=$(basename "$addon_dir")
if [[ "$id" != "$dir_base" ]]; then
  echo "warning: addon id ($id) differs from directory name ($dir_base)" >&2
fi
[[ "$id" == ".staging" || "$id" == ".trash" ]] && { echo "reserved addon id: $id" >&2; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid addon version: $version" >&2; exit 1; }

min_shell=$(value minShellVersion)
if [[ -z "$min_shell" ]]; then
  min_shell=$(value min_shell_version)
fi
if [[ -n "$min_shell" ]]; then
  [[ "$min_shell" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "invalid minShellVersion: $min_shell" >&2
    exit 1
  }
fi
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

if [[ "$entrypoint_kind" == "exec" ]]; then
  entrypoint_file="$addon_dir/$entrypoint_path"
  if head -c 2 "$entrypoint_file" | grep -q '^#!'; then
    :
  elif command -v lipo >/dev/null 2>&1; then
    archs=$(lipo -archs "$entrypoint_file" 2>/dev/null || true)
    echo "$archs" | grep -qw arm64 || {
      echo "exec entrypoint must be universal (arm64 + x86_64) or a #! script" >&2
      exit 1
    }
    echo "$archs" | grep -qw x86_64 || {
      echo "exec entrypoint must be universal (arm64 + x86_64) or a #! script" >&2
      exit 1
    }
  fi
fi
grep -q '^commands:' "$manifest" || { echo "missing commands in addon.yaml" >&2; exit 1; }
grep -q '^cleanup:' "$manifest" || { echo "missing cleanup in addon.yaml" >&2; exit 1; }

primary=$(value primary)
if [[ -n "$primary" ]]; then
  awk -v want="$primary" '
    /^commands:/ { in_commands = 1; next }
    in_commands && /^[^[:space:]-]/ { in_commands = 0 }
    in_commands && /^[[:space:]]+-[[:space:]]+id:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]+-[[:space:]]+id:[[:space:]]*/, "", line)
      gsub(/["'\'']/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      if (line == want) { found = 1 }
    }
    END { exit !found }
  ' "$manifest" || { echo "unknown primary command: $primary" >&2; exit 1; }
fi

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

if grep -q '^config:' "$manifest"; then
  python3 - "$manifest" <<'PY' || exit 1
import re, sys

try:
    import yaml
except ImportError:
    # Prefer PyYAML when present; otherwise a tiny subset parser for list-of-maps.
    yaml = None

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
allowed_types = {"string", "int", "bool", "enum"}
key_re = re.compile(r"^[a-z][a-z0-9_]*$")

def fail(msg):
    print(f"invalid config schema: {msg}", file=sys.stderr)
    sys.exit(1)

def load_config(doc):
    if not isinstance(doc, dict):
        fail("root must be a mapping")
    cfg = doc.get("config")
    if cfg is None:
        return []
    if not isinstance(cfg, list):
        fail("config must be a list")
    return cfg

if yaml is not None:
    doc = yaml.safe_load(text)
    fields = load_config(doc)
else:
    # Fallback: extract config: block items with key/type/default/values lines.
    lines = text.splitlines()
    fields = []
    i = 0
    while i < len(lines):
        if re.match(r"^config:\s*$", lines[i]) or re.match(r"^config:\s*\[", lines[i]):
            i += 1
            while i < len(lines):
                line = lines[i]
                if line and not line[0].isspace() and not line.startswith("#"):
                    break
                m = re.match(r"^\s*-\s+key:\s*(.+)$", line)
                if m:
                    field = {"key": m.group(1).strip().strip("\"'")}
                    i += 1
                    while i < len(lines):
                        sub = lines[i]
                        if re.match(r"^\s*-\s+key:", sub) or (sub and not sub[0].isspace() and not sub.startswith("#")):
                            break
                        if re.match(r"^\s+type:\s*", sub):
                            field["type"] = re.sub(r"^\s+type:\s*", "", sub).split("#")[0].strip().strip("\"'")
                        elif re.match(r"^\s+default:\s*", sub):
                            raw = re.sub(r"^\s+default:\s*", "", sub).split("#")[0].strip()
                            if raw in ("true", "false"):
                                field["default"] = raw == "true"
                            elif re.fullmatch(r"-?\d+", raw):
                                field["default"] = int(raw)
                            else:
                                field["default"] = raw.strip("\"'")
                        elif re.match(r"^\s+values:\s*", sub):
                            rest = re.sub(r"^\s+values:\s*", "", sub).split("#")[0].strip()
                            if rest.startswith("["):
                                inner = rest.strip("[]")
                                field["values"] = [p.strip().strip("\"'") for p in inner.split(",") if p.strip()]
                            else:
                                vals = []
                                i += 1
                                while i < len(lines) and re.match(r"^\s+-\s+", lines[i]):
                                    vals.append(re.sub(r"^\s+-\s+", "", lines[i]).split("#")[0].strip().strip("\"'"))
                                    i += 1
                                field["values"] = vals
                                continue
                        i += 1
                    fields.append(field)
                    continue
                i += 1
            break
        i += 1

seen = set()
for field in fields:
    if not isinstance(field, dict):
        fail("each config entry must be a mapping")
    key = field.get("key")
    typ = field.get("type")
    if not isinstance(key, str) or not key_re.match(key):
        fail(f"bad key {key!r}")
    if key in seen:
        fail(f"duplicate key {key}")
    seen.add(key)
    if typ not in allowed_types:
        fail(f"unsupported type {typ!r} for {key}")
    if "default" not in field:
        fail(f"missing default for {key}")
    default = field["default"]
    values = field.get("values")
    if typ == "enum":
        if not isinstance(values, list) or not values or not all(isinstance(v, str) for v in values):
            fail(f"enum {key} needs values")
        if default not in values:
            fail(f"default for {key} must be enum value")
    else:
        if values is not None:
            fail(f"{key} values only for enum")
        if typ == "string" and not isinstance(default, str):
            fail(f"default for {key} must be string")
        if typ == "int" and not (isinstance(default, int) and not isinstance(default, bool)):
            fail(f"default for {key} must be int")
        if typ == "bool" and not isinstance(default, bool):
            fail(f"default for {key} must be bool")
PY
fi

if grep -q '^permissions:' "$manifest"; then
  awk '
    function is_known(p) {
      return (p == "accessibility" || p == "input-monitoring" || p == "camera" ||
              p == "microphone" || p == "screen-recording" || p == "network" ||
              p == "clipboard" || p == "background")
    }
    /^permissions:/ {
      line = $0
      sub(/^permissions:[[:space:]]*/, "", line)
      if (line != "" && line !~ /^\[/) {
        # inline list not used; fall through to list items
      }
      in_p = 1
      if (line ~ /^\[/) {
        gsub(/[][,]/, " ", line)
        n = split(line, parts, /[[:space:]]+/)
        for (i = 1; i <= n; i++) {
          tok = parts[i]
          gsub(/["'\'']/, "", tok)
          if (tok == "") continue
          if (!is_known(tok)) { print "invalid permission: " tok > "/dev/stderr"; exit 1 }
        }
        in_p = 0
      }
      next
    }
    in_p && /^[^[:space:]-]/ { in_p = 0 }
    in_p && /^[[:space:]]*-[[:space:]]*/ {
      tok = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", tok)
      gsub(/["'\'']/, "", tok)
      sub(/[[:space:]]*#.*$/, "", tok)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", tok)
      if (tok == "") next
      if (!is_known(tok)) { print "invalid permission: " tok > "/dev/stderr"; exit 1 }
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

if [[ -n "$(find "$addon_dir" \( -name .build -o -name .git -o -name .swiftpm \) -prune -o -name '*.plist' -print -quit)" ]]; then
  echo "addon must not ship a .plist; the shell authors launchd agents" >&2
  exit 1
fi

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
