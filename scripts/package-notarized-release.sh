#!/usr/bin/env bash
set -euo pipefail

export SILENT_SWITCH_SIGNING_MODE="${SILENT_SWITCH_SIGNING_MODE:-developer-id}"

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

NOTARY_PROFILE="${SILENT_SWITCH_NOTARY_PROFILE:-silent-switch-notary}"
NOTARY_WAIT_TIMEOUT="${SILENT_SWITCH_NOTARY_WAIT_TIMEOUT:-30m}"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "error: SILENT_SWITCH_NOTARY_PROFILE must not be empty." >&2
  exit 1
fi

submit_and_wait() {
  local path="$1"
  local output_file
  local submission_id

  output_file="$(/usr/bin/mktemp)"
  if /usr/bin/xcrun notarytool submit "$path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout "$NOTARY_WAIT_TIMEOUT" 2>&1 | /usr/bin/tee "$output_file"; then
    /bin/rm -f "$output_file"
    return 0
  fi

  submission_id="$(/usr/bin/sed -n 's/^  id: \([0-9a-fA-F-][0-9a-fA-F-]*\)$/\1/p' "$output_file" | /usr/bin/tail -n 1)"
  /bin/rm -f "$output_file"

  if [[ -z "$submission_id" ]]; then
    return 1
  fi

  echo "warning: notarytool submit failed after receiving submission id; continuing with notarytool wait: $submission_id" >&2
  /usr/bin/xcrun notarytool wait "$submission_id" \
    --keychain-profile "$NOTARY_PROFILE" \
    --timeout "$NOTARY_WAIT_TIMEOUT"
}

"$PROJECT_ROOT/scripts/build-release.sh" >/dev/null

APP_PATH="$BUILD_DIR/Release/Silent Switch.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found: $APP_PATH" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if ! /usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1 | /usr/bin/grep -F "Authority=Developer ID Application" >/dev/null; then
  echo "error: release app is not signed with a Developer ID Application identity." >&2
  exit 1
fi

if /usr/bin/codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | /usr/bin/grep -F "com.apple.security.get-task-allow" >/dev/null; then
  echo "error: release app contains get-task-allow entitlement and cannot be notarized." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ARCH="$(uname -m)"
PACKAGE_BASENAME="SilentSwitch-${VERSION}-macos-${ARCH}"
DIST_DIR="$PROJECT_ROOT/dist"
NOTARIZATION_DIR="$BUILD_DIR/Notarization"
APP_NOTARY_ZIP="$NOTARIZATION_DIR/$PACKAGE_BASENAME-app.zip"
DMG_PATH="$DIST_DIR/$PACKAGE_BASENAME.dmg"
ZIP_PATH="$DIST_DIR/$PACKAGE_BASENAME.zip"

mkdir -p "$NOTARIZATION_DIR"
rm -f "$APP_NOTARY_ZIP"

/usr/bin/ditto \
  -c -k --keepParent --norsrc --noextattr --noqtn --noacl \
  "$APP_PATH" \
  "$APP_NOTARY_ZIP"

submit_and_wait "$APP_NOTARY_ZIP"

/usr/bin/xcrun stapler staple "$APP_PATH"
/usr/bin/xcrun stapler validate "$APP_PATH"

SILENT_SWITCH_SKIP_BUILD=1 "$PROJECT_ROOT/scripts/package-release.sh" >/dev/null

if [[ ! -f "$DMG_PATH" ]]; then
  echo "error: dmg not found: $DMG_PATH" >&2
  exit 1
fi

/usr/bin/codesign --force --sign "$LOCAL_CODE_SIGN_IDENTITY" --timestamp "$DMG_PATH"
/usr/bin/codesign --verify --verbose=2 "$DMG_PATH"

submit_and_wait "$DMG_PATH"

/usr/bin/xcrun stapler staple "$DMG_PATH"
/usr/bin/xcrun stapler validate "$DMG_PATH"

/usr/sbin/spctl -a -vv --type open --context context:primary-signature "$DMG_PATH"
/usr/sbin/spctl -a -vv --type execute "$APP_PATH"

echo "$DMG_PATH"
echo "$ZIP_PATH"
