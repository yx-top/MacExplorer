#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacExplorer"
BUILD_CONFIG="${1:-debug}"
ARCH="${2:-native}"
DIST_DIR="$ROOT_DIR/dist"
APP_BASENAME="${APP_NAME}.app"
if [[ "$ARCH" != "native" ]]; then
    APP_BASENAME="${APP_NAME}-${ARCH}.app"
fi
APP_DIR="$DIST_DIR/$APP_BASENAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/Resources/MacExplorer.icns"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VERSION_FILE="$ROOT_DIR/VERSION"
EXECUTABLE_OUTPUT="$MACOS_DIR/$APP_NAME"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Missing VERSION file at $VERSION_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$VERSION_FILE"
: "${APP_VERSION:?APP_VERSION is required in VERSION}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required in VERSION}"

case "$ARCH" in
    native)
        swift build --configuration "$BUILD_CONFIG"
        EXECUTABLE_PATH="$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME"
        ;;
    arm64|x86_64)
        swift build --configuration "$BUILD_CONFIG" --arch "$ARCH"
        EXECUTABLE_PATH="$ROOT_DIR/.build/$ARCH-apple-macosx/$BUILD_CONFIG/$APP_NAME"
        ;;
    universal)
        swift build --configuration "$BUILD_CONFIG" --arch arm64
        swift build --configuration "$BUILD_CONFIG" --arch x86_64
        ARM64_EXECUTABLE="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG/$APP_NAME"
        X86_64_EXECUTABLE="$ROOT_DIR/.build/x86_64-apple-macosx/$BUILD_CONFIG/$APP_NAME"
        ;;
    *)
        echo "Unsupported arch '$ARCH'. Use native, arm64, x86_64, or universal." >&2
        exit 1
        ;;
esac

if [[ ! -f "$ICON_SOURCE" ]]; then
    (cd "$ROOT_DIR" && swift scripts/generate_app_icon.swift)
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
if [[ "$ARCH" == "universal" ]]; then
    lipo -create -output "$EXECUTABLE_OUTPUT" "$ARM64_EXECUTABLE" "$X86_64_EXECUTABLE"
else
    cp "$EXECUTABLE_PATH" "$EXECUTABLE_OUTPUT"
fi
cp "$ICON_SOURCE" "$RESOURCES_DIR/MacExplorer.icns"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>local.macexplorer.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>MacExplorer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
