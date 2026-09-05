#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/package-addon.sh addons/jugnu.mic-mute dist/
# produces dist/<id>-<version>.zip and prints sha256

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <addon-dir> <dist-dir>" >&2
  exit 1
fi

addon_dir=$(cd "$1" && pwd)
dist_dir=$2
mkdir -p "$dist_dir"
dist_dir=$(cd "$dist_dir" && pwd)

manifest="$addon_dir/addon.yaml"
if [[ ! -f "$manifest" ]]; then
  echo "missing addon.yaml in $addon_dir" >&2
  exit 1
fi

validator="$(dirname "$0")/validate-addon.sh"
"$validator" "$addon_dir" >&2

id=$(sed -n 's/^id:[[:space:]]*//p' "$manifest" | head -1 | tr -d '"')
version=$(sed -n 's/^version:[[:space:]]*//p' "$manifest" | head -1 | tr -d '"')
if [[ -z "$id" || -z "$version" ]]; then
  echo "could not parse id/version from addon.yaml" >&2
  exit 1
fi

zip_name="${id}-${version}.zip"
zip_path="$dist_dir/$zip_name"
rm -f "$zip_path"

(
  cd "$(dirname "$addon_dir")"
  zip -qr "$zip_path" "$(basename "$addon_dir")"
)

shasum -a 256 "$zip_path" | awk '{print $1}'
echo "$zip_path" >&2
