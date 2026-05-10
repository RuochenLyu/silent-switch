#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/xcode-env.sh"

rm -rf "$BUILD_DIR"
