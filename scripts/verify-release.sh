#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

"$PROJECT_ROOT/scripts/test.sh" >/dev/null
"$PROJECT_ROOT/scripts/build-release.sh" >/dev/null

APP_PATH="$BUILD_DIR/Release/Silent Switch.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
BINARY_PATH="$APP_PATH/Contents/MacOS/Silent Switch"

/usr/bin/plutil -lint "$PROJECT_ROOT/SilentSwitch/Resources/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP_PATH"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
ARCHS="$(/usr/bin/lipo -archs "$BINARY_PATH")"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: release version must use semantic versioning: $VERSION" >&2
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: build number must be a positive integer: $BUILD_NUMBER" >&2
  exit 1
fi
if [[ "$ARCHS" != *"arm64"* || "$ARCHS" != *"x86_64"* ]]; then
  echo "error: release must contain arm64 and x86_64: $ARCHS" >&2
  exit 1
fi

echo "Silent Switch $VERSION ($BUILD_NUMBER): verified [$ARCHS]"
