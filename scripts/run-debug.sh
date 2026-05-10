#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

APP_PATH="$BUILD_DIR/Debug/Silent Switch.app"

if [[ ! -d "$APP_PATH" ]]; then
  "$PROJECT_ROOT/scripts/build-debug.sh" >/dev/null
fi

/usr/bin/open "$APP_PATH"
