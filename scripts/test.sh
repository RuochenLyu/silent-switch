#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

DERIVED_DATA_PATH="${TEST_DERIVED_DATA_PATH:-$DERIVED_DATA_ROOT/Test}"

/usr/bin/xcrun xcodebuild test \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -destination "$XCODE_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${XCODE_CODE_SIGN_ARGS[@]}"
