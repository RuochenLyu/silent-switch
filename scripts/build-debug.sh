#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

DERIVED_DATA_PATH="${DEBUG_DERIVED_DATA_PATH:-$DERIVED_DATA_ROOT/Debug}"

/usr/bin/xcrun xcodebuild build \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -configuration Debug \
  -destination "$XCODE_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR/Debug" \
  "${XCODE_CODE_SIGN_ARGS[@]}"

echo "$BUILD_DIR/Debug/Silent Switch.app"
