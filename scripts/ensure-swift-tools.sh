#!/usr/bin/env bash
# Install the SwiftFormat and SwiftLint builds CI lints with.
# They live in ~/.local/share/jugnu/swift-tools/bin. The lint scripts and GitHub Actions
# put that directory ahead of Homebrew, so a newer bottle cannot change the result.
set -euo pipefail

# SwiftLint 0.65+ loads sourcekitd from the Xcode toolchain, not Command Line Tools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

bindir="${JUGNU_SWIFT_TOOLS_BIN:-$HOME/.local/share/jugnu/swift-tools/bin}"
mkdir -p "$bindir"

tool_version() {
  local name=$1
  if [[ "$name" == "swiftformat" ]]; then
    "$bindir/$name" --version
  else
    "$bindir/$name" version
  fi
}

install_zip() {
  local name=$1 version=$2 url=$3 sha=$4
  local bin="$bindir/$name"
  if [[ -x "$bin" ]] && [[ "$(tool_version "$name")" == "$version" ]]; then
    return 0
  fi
  local tmp
  tmp=$(mktemp -d)
  echo "Installing $name $version" >&2
  curl -fsSL -o "$tmp/tool.zip" "$url"
  local actual
  actual=$(shasum -a 256 "$tmp/tool.zip" | awk '{print $1}')
  if [[ "$actual" != "$sha" ]]; then
    rm -rf "$tmp"
    echo "error: $name $version zip sha256 is $actual, expected $sha" >&2
    exit 1
  fi
  unzip -qo "$tmp/tool.zip" -d "$tmp/out"
  local found
  found=$(find "$tmp/out" -type f -name "$name" | head -1)
  if [[ -z "$found" ]]; then
    rm -rf "$tmp"
    echo "error: $name binary missing from $url" >&2
    exit 1
  fi
  cp "$found" "$bin"
  chmod +x "$bin"
  rm -rf "$tmp"
}

install_zip swiftformat 0.62.1 \
  "https://github.com/nicklockwood/SwiftFormat/releases/download/0.62.1/swiftformat.zip" \
  "7cb1cb1fae04932047c7015441c543848e8e60e1572d808d080e0a1f1661114a"

install_zip swiftlint 0.65.1 \
  "https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip" \
  "c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$bindir" >> "$GITHUB_PATH"
fi
