#!/usr/bin/env bash
# Format Swift sources in place. Extra args are paths (pre-commit).
# Use --lint for check-only (CI / make lint-swift).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
"$root/scripts/ensure-swift-tools.sh"

lint_only=0
args=()
for a in "$@"; do
  if [[ "$a" == "--lint" ]]; then
    lint_only=1
  else
    args+=("$a")
  fi
done

if [[ ${#args[@]} -eq 0 ]]; then
  args=(shell/App shell/Sources shell/Tests shell/TestsExtended)
fi

if [[ "$lint_only" -eq 1 ]]; then
  swiftformat --lint --config "$root/.swiftformat" "${args[@]}"
else
  swiftformat --config "$root/.swiftformat" "${args[@]}"
fi
