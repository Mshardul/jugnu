#!/usr/bin/env bash
# Lint Swift sources. Extra args are passed through (pre-commit supplies paths).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
"$root/scripts/ensure-swift-tools.sh"
if [[ $# -gt 0 ]]; then
  swiftlint lint --config "$root/.swiftlint.yml" "$@"
else
  swiftlint lint --config "$root/.swiftlint.yml"
fi
