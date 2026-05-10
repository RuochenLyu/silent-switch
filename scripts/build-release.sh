#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

DERIVED_DATA_PATH="${RELEASE_DERIVED_DATA_PATH:-$DERIVED_DATA_ROOT/Release}"

/usr/bin/xcrun xcodebuild build \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -configuration Release \
  -destination "$XCODE_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" \
  "${XCODE_CODE_SIGN_ARGS[@]}"

echo "$BUILD_DIR/Release/Silent Switch.app"
