#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/_extract_commands.sh <addon.yaml path>
# Emits a JSON array of {id,title,subtitle} parsed from the manifest's
# `commands:` block. Internal helper for sync-registry-commands.sh.

manifest="$1"
awk '
  BEGIN { print "["; first=1 }
  /^commands:/ { in_commands=1; next }
  in_commands && /^  - id:/ {
    if (!first) print ",";
    first=0;
    sub(/^  - id:[[:space:]]*/, ""); gsub(/["\047]/, "");
    id=$0
    next
  }
  in_commands && /^    title:/ {
    sub(/^    title:[[:space:]]*/, ""); gsub(/["\047]/, ""); title=$0; next
  }
  in_commands && /^    subtitle:/ {
    sub(/^    subtitle:[[:space:]]*/, ""); gsub(/["\047]/, ""); subtitle=$0;
    printf "{\"id\":\"%s\",\"title\":\"%s\",\"subtitle\":\"%s\"}", id, title, subtitle
    next
  }
  in_commands && /^[a-z]/ && !/^  / { in_commands=0 }
  END { print "]" }
' "$manifest"
