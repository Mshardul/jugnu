#!/usr/bin/env bash
# Install SwiftFormat + SwiftLint via Homebrew when missing (same tools as CI).
set -euo pipefail

# SwiftLint 0.65+ loads sourcekitd from the Xcode toolchain, not Command Line Tools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

need() {
  local name=$1
  if command -v "$name" >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "error: $name is not on PATH and Homebrew is not available." >&2
    echo "Install Homebrew, then: brew install swiftformat swiftlint" >&2
    exit 1
  fi
  echo "Installing $name via Homebrew…" >&2
  HOMEBREW_NO_AUTO_UPDATE=1 brew install "$name"
}

need swiftformat
need swiftlint
