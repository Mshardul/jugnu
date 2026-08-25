#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/package-helper-clock.sh [dist-dir]
# builds helpers/clock release binary, stages helper.yaml + bin/clock, prints sha256

dist_dir=${1:-dist}
repo_root=$(cd "$(dirname "$0")/.." && pwd)
helper_dir="$repo_root/helpers/clock"
dist_dir=$(mkdir -p "$repo_root/$dist_dir" && cd "$repo_root/$dist_dir" && pwd)

manifest="$helper_dir/helper.yaml"
if [[ ! -f "$manifest" ]]; then
  echo "missing helper.yaml in $helper_dir" >&2
  exit 1
fi

id=$(sed -n 's/^id:[[:space:]]*//p' "$manifest" | head -1 | tr -d '"')
version=$(sed -n 's/^version:[[:space:]]*//p' "$manifest" | head -1 | tr -d '"')
if [[ -z "$id" || -z "$version" ]]; then
  echo "could not parse id/version from helper.yaml" >&2
  exit 1
fi

binary="$helper_dir/.build/release/clock"
echo "building release binary..." >&2
(
  cd "$helper_dir"
  swift build -c release
)
if [[ ! -x "$binary" ]]; then
  echo "missing release binary at $binary" >&2
  exit 1
fi

staging="$dist_dir/${id}-${version}"
rm -rf "$staging"
mkdir -p "$staging/bin"
cp "$manifest" "$staging/helper.yaml"
cp "$binary" "$staging/bin/clock"
chmod +x "$staging/bin/clock"

zip_name="${id}-${version}.zip"
zip_path="$dist_dir/$zip_name"
rm -f "$zip_path"
(
  cd "$staging"
  zip -qr "$zip_path" helper.yaml bin
)

shasum -a 256 "$zip_path" | awk '{print $1}'
echo "$zip_path" >&2
