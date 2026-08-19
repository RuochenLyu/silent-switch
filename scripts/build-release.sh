#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

DERIVED_DATA_PATH="${RELEASE_DERIVED_DATA_PATH:-$DERIVED_DATA_ROOT/Release}"
RELEASE_DESTINATION="${XCODE_RELEASE_DESTINATION:-generic/platform=macOS}"
RELEASE_ARCHS="${SILENT_SWITCH_RELEASE_ARCHS:-arm64 x86_64}"

/usr/bin/xcrun xcodebuild build \
  -project "$XCODE_PROJECT" \
  -scheme "$XCODE_SCHEME" \
  -configuration Release \
  -destination "$RELEASE_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" \
  ARCHS="$RELEASE_ARCHS" \
  ONLY_ACTIVE_ARCH=NO \
  ${XCODE_CODE_SIGN_ARGS[@]+"${XCODE_CODE_SIGN_ARGS[@]}"}

echo "$BUILD_DIR/Release/Silent Switch.app"
