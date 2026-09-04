#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/package-helper-python-runtime.sh [dist-dir]
# stages helper.yaml + arch/ + bin/python3, prints sha256 on stdout

dist_dir=${1:-dist}
repo_root=$(cd "$(dirname "$0")/.." && pwd)
helper_dir="$repo_root/helpers/python-runtime"
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

if [[ ! -x "$helper_dir/bin/python3" ]]; then
  echo "missing bin/python3 — run scripts/fetch-python-runtime.sh first" >&2
  exit 1
fi

staging="$dist_dir/${id}-${version}"
rm -rf "$staging"
mkdir -p "$staging"
cp "$manifest" "$staging/helper.yaml"
cp -R "$helper_dir/bin" "$staging/bin"
cp -R "$helper_dir/arch" "$staging/arch"

zip_name="${id}-${version}.zip"
zip_path="$dist_dir/$zip_name"
rm -f "$zip_path"
(
  cd "$staging"
  zip -qr "$zip_path" helper.yaml bin arch
)

shasum -a 256 "$zip_path" | awk '{print $1}'
echo "$zip_path" >&2
