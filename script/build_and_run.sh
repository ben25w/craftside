#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CraftSide"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
PROJECT="$ROOT_DIR/CraftSide.xcodeproj"
SCHEME="CraftSide"
CONFIGURATION="Debug"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
INSTALLED_APP="/Applications/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rm -rf "$APP_BUNDLE"
xattr -cr "$ROOT_DIR/CraftSide" "$DERIVED_DATA" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  build

xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true
/usr/bin/codesign --force --deep --sign - --entitlements "$ROOT_DIR/CraftSide/CraftSide.entitlements" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

install_app() {
  rm -rf "$INSTALLED_APP"
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_APP"
  xattr -cr "$INSTALLED_APP" >/dev/null 2>&1 || true
  /usr/bin/codesign --force --deep --sign - --entitlements "$ROOT_DIR/CraftSide/CraftSide.entitlements" "$INSTALLED_APP"
  /usr/bin/open -n "$INSTALLED_APP"
}

case "$MODE" in
  run)
    open_app
    ;;
  --install|install)
    install_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--install|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
