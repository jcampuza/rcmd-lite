#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIGURATION=${1:-${CONFIGURATION:-debug}}
SIGNING_IDENTITY=${RCMD_SIGNING_IDENTITY:-}
VERSION=${RCMD_VERSION:-}
BUILD_NUMBER=${RCMD_BUILD_NUMBER:-}

case "$CONFIGURATION" in
  debug)
    APP_NAME="RcmdLite Debug"
    BUNDLE_ID="com.josephcampuzano.rcmd-lite.debug"
    DEFAULT_APP="$HOME/Applications/RcmdLite Debug.app"
    ;;
  release)
    APP_NAME="RcmdLite"
    BUNDLE_ID="com.josephcampuzano.rcmd-lite"
    DEFAULT_APP="$HOME/Applications/RcmdLite.app"
    ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

APP=${RCMD_APP_PATH:-"$DEFAULT_APP"}

has_identity() {
  security find-identity -p codesigning -v 2>/dev/null | grep -F "\"$1\"" >/dev/null 2>&1
}

if [ -z "$SIGNING_IDENTITY" ] && has_identity "RcmdLite Development"; then
  SIGNING_IDENTITY="RcmdLite Development"
fi

if [ -z "$SIGNING_IDENTITY" ]; then
  SIGNING_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null \
    | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
    | sed -n '1p')
fi

swift build --package-path "$ROOT" --configuration "$CONFIGURATION" --product rcmd-lite
BIN_DIR=$(swift build --package-path "$ROOT" --configuration "$CONFIGURATION" --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/rcmd-lite" "$APP/Contents/MacOS/RcmdLite"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/RcmdLite.icns" "$APP/Contents/Resources/RcmdLite.icns"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Contents/Info.plist"
plutil -replace CFBundleName -string "$APP_NAME" "$APP/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$APP_NAME" "$APP/Contents/Info.plist"
if [ -n "$VERSION" ]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
fi
if [ -n "$BUILD_NUMBER" ]; then
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
fi
xattr -cr "$APP"
if [ "$SIGNING_IDENTITY" = "-" ]; then
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
  echo "Signed ad hoc." >&2
elif [ -n "$SIGNING_IDENTITY" ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
  echo "Signed with stable identity: $SIGNING_IDENTITY" >&2
else
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
  echo "WARNING: No code-signing identity found; using ad-hoc signing." >&2
  echo "         TCC permissions may reset after every rebuild." >&2
  echo "         See docs/development-signing.md for the one-time fix." >&2
fi

echo "Built $CONFIGURATION app:"
echo "$APP"
