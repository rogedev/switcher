#!/usr/bin/env bash
# Local development build + run. Builds Release (active arch only) and re-signs with
# the stable "Switcher Dev" identity from setup-dev-signing.sh, so the Accessibility /
# Screen Recording grants you give it survive rebuilds.
#
# Run scripts/setup-dev-signing.sh once first. For distribution use `make package`.
#
# Usage: scripts/dev-build.sh [--run]
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="Switcher Dev"
APP="DerivedData/Build/Products/Release/Switcher.app"

xcodegen generate
xcodebuild -project Switcher.xcodeproj -scheme Switcher -configuration Release \
  -derivedDataPath DerivedData ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES build >/dev/null

codesign --force --deep --sign "$IDENTITY" --entitlements Switcher.entitlements "$APP"
echo "Signed with: $IDENTITY"
codesign -d -r- "$APP" 2>&1 | grep -i designated || true

if [[ "${1:-}" == "--run" ]]; then
  pkill -x Switcher 2>/dev/null || true
  # Wait until the old instance is fully gone, else `open` just re-activates it
  # (and you'd keep seeing the previous build).
  for _ in $(seq 1 25); do pgrep -x Switcher >/dev/null || break; sleep 0.2; done
  open "$APP"
  echo "Launched $APP"
fi
