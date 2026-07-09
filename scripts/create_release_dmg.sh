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
STAGING_DIR="$DIST_DIR/.dmg-staging"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/package_app.sh" "$BUILD_CONFIG" "$ARCH" >/dev/null

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
ARCHIVE_NAME="$APP_NAME-$VERSION-$BUILD_NUMBER-$ARCHIVE_ARCH"
DMG_PATH="$DIST_DIR/$ARCHIVE_NAME.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$STAGING_DIR"

ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

(
    cd "$DIST_DIR"
    shasum -a 256 "$ARCHIVE_NAME.dmg" > "$ARCHIVE_NAME.dmg.sha256"
)

echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
