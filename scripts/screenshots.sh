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

echo "==> Building the app and screenshot tests"
xcodebuild build-for-testing \
  -project Jugnu.xcodeproj \
  -scheme Screenshots \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO

# The UI runner resolves the host as Debug/Jugnu. The product is Debug/Jugnu.app.
PRODUCTS="$SHELL_DIR/DerivedData/Build/Products/Debug"
if [[ ! -d "$PRODUCTS/Jugnu.app" ]]; then
  echo "!! Jugnu.app was not built." >&2
  exit 1
fi
ln -sfn Jugnu.app "$PRODUCTS/Jugnu"
trap 'rm -f "$PRODUCTS/Jugnu"' EXIT

export JUGNU_REPO_ADDONS="$REPO_ROOT/addons"
export TEST_RUNNER_JUGNU_REPO_ADDONS="$REPO_ROOT/addons"

echo "==> Running the screenshot walk (this opens the app and clicks through it — don't touch the mouse)"
rm -rf "$RESULT_BUNDLE"
LOG="$SHELL_DIR/DerivedData/screenshots.log"
set +e
xcodebuild test-without-building \
  -project Jugnu.xcodeproj \
  -scheme Screenshots \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -test-timeouts-enabled NO \
  >"$LOG" 2>&1
TEST_STATUS=$?
set -e
grep -E "SHOT:|Test Case '|passed \\(|failed \\(|\\*\\* TEST|Testing failed|error:" "$LOG" || true
if [[ "$TEST_STATUS" -ne 0 ]]; then
  xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" || true
fi

echo "==> Extracting screenshots -> $OUT_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
python3 "$REPO_ROOT/scripts/extract-screenshots.py" "$RESULT_BUNDLE" "$OUT_DIR"

COUNT=$(find "$OUT_DIR" -name '*.png' | wc -l | tr -d ' ')
echo "==> $COUNT screenshot(s) in $OUT_DIR"

if [ "$TEST_STATUS" -ne 0 ] && [ "$COUNT" -eq 0 ]; then
  echo "!! Test run failed and produced no screenshots." >&2
  echo "!! See $LOG" >&2
  exit 1
fi
