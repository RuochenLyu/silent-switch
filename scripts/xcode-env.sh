#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PROJECT_ROOT
export XCODE_PROJECT="${XCODE_PROJECT:-$PROJECT_ROOT/SilentSwitch.xcodeproj}"
export XCODE_SCHEME="${XCODE_SCHEME:-SilentSwitch}"
export BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
export DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$BUILD_DIR/DerivedData}"
export XCODE_DESTINATION="${XCODE_DESTINATION:-platform=macOS,arch=$(uname -m)}"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! /usr/bin/xcrun xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild is not available. Install Xcode or set DEVELOPER_DIR." >&2
  exit 1
fi

DEFAULT_LOCAL_CODE_SIGN_IDENTITY="Silent Switch Local Development"
REQUESTED_CODE_SIGN_IDENTITY="${SILENT_SWITCH_CODE_SIGN_IDENTITY:-}"
LOCAL_CODE_SIGN_IDENTITY=""
XCODE_CODE_SIGN_ARGS=()

if [[ -n "$REQUESTED_CODE_SIGN_IDENTITY" ]]; then
  if ! /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F "\"$REQUESTED_CODE_SIGN_IDENTITY\"" >/dev/null; then
    echo "error: code signing identity not found: $REQUESTED_CODE_SIGN_IDENTITY" >&2
    exit 1
  fi

  LOCAL_CODE_SIGN_IDENTITY="$REQUESTED_CODE_SIGN_IDENTITY"
elif /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F "\"$DEFAULT_LOCAL_CODE_SIGN_IDENTITY\"" >/dev/null; then
  LOCAL_CODE_SIGN_IDENTITY="$DEFAULT_LOCAL_CODE_SIGN_IDENTITY"
else
  LOCAL_CODE_SIGN_IDENTITY="$(
    /usr/bin/security find-identity -v -p codesigning \
      | /usr/bin/sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
      | /usr/bin/head -n 1
  )"
fi

if [[ -n "$LOCAL_CODE_SIGN_IDENTITY" ]]; then
  XCODE_CODE_SIGN_ARGS=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$LOCAL_CODE_SIGN_IDENTITY"
    DEVELOPMENT_TEAM=
  )
fi
