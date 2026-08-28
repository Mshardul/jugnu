#!/usr/bin/env bash
# Drive the real Jugnu app through every page and save screenshots to screenshots/.
#
#   make screenshots        # full walk
#
# Requires: a GUI login session (not SSH/headless), and Accessibility +
# Screen Recording permission granted to whatever runs this (Terminal / Xcode).
# The test target is never run by `make test` or CI.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_ROOT/shell"
OUT_DIR="$REPO_ROOT/screenshots"
RESULT_BUNDLE="$SHELL_DIR/DerivedData/screenshots.xcresult"

cd "$SHELL_DIR"

echo "==> Regenerating Xcode project"
xcodegen generate >/dev/null

echo "==> Running the screenshot walk (this opens the app and clicks through it — don't touch the mouse)"
rm -rf "$RESULT_BUNDLE"
set +e
xcodebuild test \
  -project Jugnu.xcodeproj \
  -scheme Screenshots \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  JUGNU_REPO_ADDONS="$REPO_ROOT/addons" \
  -test-timeouts-enabled NO \
  2>&1 | grep -E "SHOT:|Test Case '|passed \(|failed \(|\*\* TEST| error:" || true
TEST_STATUS=${PIPESTATUS[0]}
set -e

echo "==> Extracting screenshots -> $OUT_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
python3 "$REPO_ROOT/scripts/extract-screenshots.py" "$RESULT_BUNDLE" "$OUT_DIR"

COUNT=$(find "$OUT_DIR" -name '*.png' | wc -l | tr -d ' ')
echo "==> $COUNT screenshot(s) in $OUT_DIR"

if [ "$TEST_STATUS" -ne 0 ] && [ "$COUNT" -eq 0 ]; then
  echo "!! Test run failed and produced no screenshots." >&2
  echo "!! Most common cause: Accessibility / Screen Recording not granted to the test runner." >&2
  echo "!! Grant them in System Settings > Privacy & Security, then re-run." >&2
  exit 1
fi
