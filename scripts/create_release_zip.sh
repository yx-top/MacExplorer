#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacExplorer"
BUILD_CONFIG="${1:-release}"
ARCH="${2:-native}"
DIST_DIR="$ROOT_DIR/dist"
APP_BASENAME="${APP_NAME}.app"
ARCHIVE_ARCH="macos"
if [[ "$ARCH" != "native" ]]; then
    APP_BASENAME="${APP_NAME}-${ARCH}.app"
    ARCHIVE_ARCH="macos-$ARCH"
fi
APP_DIR="$DIST_DIR/$APP_BASENAME"
INFO_PLIST="$APP_DIR/Contents/Info.plist"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/package_app.sh" "$BUILD_CONFIG" "$ARCH" >/dev/null

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
ARCHIVE_NAME="$APP_NAME-$VERSION-$BUILD_NUMBER-$ARCHIVE_ARCH"
ZIP_PATH="$DIST_DIR/$ARCHIVE_NAME.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"

(
    cd "$DIST_DIR"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BASENAME" "$ARCHIVE_NAME.zip"
    shasum -a 256 "$ARCHIVE_NAME.zip" > "$ARCHIVE_NAME.zip.sha256"
)

echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
