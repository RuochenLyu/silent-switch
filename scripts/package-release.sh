#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

"$PROJECT_ROOT/scripts/build-release.sh" >/dev/null

APP_PATH="$BUILD_DIR/Release/Silent Switch.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found: $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ARCH="$(uname -m)"
PACKAGE_BASENAME="SilentSwitch-${VERSION}-macos-${ARCH}"
DIST_DIR="$PROJECT_ROOT/dist"
STAGING_DIR="$BUILD_DIR/Package/$PACKAGE_BASENAME"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

/usr/bin/ditto "$APP_PATH" "$STAGING_DIR/Silent Switch.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DIST_DIR/$PACKAGE_BASENAME.zip" "$DIST_DIR/$PACKAGE_BASENAME.dmg"

/usr/bin/ditto \
  -c -k --keepParent --norsrc --noextattr --noqtn --noacl \
  "$APP_PATH" \
  "$DIST_DIR/$PACKAGE_BASENAME.zip"

/usr/bin/hdiutil create \
  -volname "Silent Switch" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DIST_DIR/$PACKAGE_BASENAME.dmg" >/dev/null

echo "$DIST_DIR/$PACKAGE_BASENAME.dmg"
echo "$DIST_DIR/$PACKAGE_BASENAME.zip"
