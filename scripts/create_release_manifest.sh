#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacExplorer"
DIST_DIR="$ROOT_DIR/dist"
ARCH="${1:-native}"
APP_BASENAME="${APP_NAME}.app"
ARCHIVE_ARCH="macos"
if [[ "$ARCH" != "native" ]]; then
    APP_BASENAME="${APP_NAME}-${ARCH}.app"
    ARCHIVE_ARCH="macos-$ARCH"
fi
APP_DIR="$DIST_DIR/$APP_BASENAME"
INFO_PLIST="$APP_DIR/Contents/Info.plist"

cd "$ROOT_DIR"

if [[ ! -d "$APP_DIR" ]]; then
    "$ROOT_DIR/scripts/package_app.sh" release "$ARCH" >/dev/null
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")"
MIN_SYSTEM_VERSION="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST")"
ARCHIVE_NAME="$APP_NAME-$VERSION-$BUILD_NUMBER-$ARCHIVE_ARCH"

ZIP_PATH="$DIST_DIR/$ARCHIVE_NAME.zip"
ZIP_CHECKSUM_PATH="$ZIP_PATH.sha256"
DMG_PATH="$DIST_DIR/$ARCHIVE_NAME.dmg"
DMG_CHECKSUM_PATH="$DMG_PATH.sha256"
MANIFEST_PATH="$DIST_DIR/$ARCHIVE_NAME.manifest.json"

if [[ ! -f "$ZIP_PATH" || ! -f "$ZIP_CHECKSUM_PATH" ]]; then
    "$ROOT_DIR/scripts/create_release_zip.sh" release "$ARCH" >/dev/null
fi

if [[ ! -f "$DMG_PATH" || ! -f "$DMG_CHECKSUM_PATH" ]]; then
    "$ROOT_DIR/scripts/create_release_dmg.sh" release "$ARCH" >/dev/null
fi

(
    cd "$DIST_DIR"
    shasum -a 256 -c "$(basename "$ZIP_CHECKSUM_PATH")" >/dev/null
    shasum -a 256 -c "$(basename "$DMG_CHECKSUM_PATH")" >/dev/null
)

ZIP_SHA="$(awk '{print $1}' "$ZIP_CHECKSUM_PATH")"
DMG_SHA="$(awk '{print $1}' "$DMG_CHECKSUM_PATH")"
ZIP_SIZE="$(stat -f "%z" "$ZIP_PATH")"
DMG_SIZE="$(stat -f "%z" "$DMG_PATH")"
GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
GIT_TAG="$(git describe --tags --exact-match 2>/dev/null || true)"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$MANIFEST_PATH" <<JSON
{
  "appName": "$APP_NAME",
  "version": "$VERSION",
  "build": "$BUILD_NUMBER",
  "architecture": "$ARCHIVE_ARCH",
  "bundleIdentifier": "$BUNDLE_ID",
  "minimumSystemVersion": "$MIN_SYSTEM_VERSION",
  "generatedAt": "$GENERATED_AT",
  "gitCommit": "$GIT_COMMIT",
  "gitTag": "$GIT_TAG",
  "artifacts": [
    {
      "type": "zip",
      "fileName": "$ARCHIVE_NAME.zip",
      "sizeBytes": $ZIP_SIZE,
      "sha256": "$ZIP_SHA"
    },
    {
      "type": "dmg",
      "fileName": "$ARCHIVE_NAME.dmg",
      "sizeBytes": $DMG_SIZE,
      "sha256": "$DMG_SHA"
    }
  ]
}
JSON

python3 -m json.tool "$MANIFEST_PATH" >/dev/null

echo "$MANIFEST_PATH"
