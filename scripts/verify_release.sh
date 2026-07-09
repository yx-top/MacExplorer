#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/MacExplorer.app"
INFO_PLIST="$APP_DIR/Contents/Info.plist"
APP_ICON="$APP_DIR/Contents/Resources/MacExplorer.icns"
SOURCE_ICON="$ROOT_DIR/Resources/MacExplorer.icns"

cd "$ROOT_DIR"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

echo "==> Checking release prerequisites"
for command_name in swift plutil codesign cmp shasum hdiutil python3 rg open osascript pgrep ditto git awk sed stat; do
    require_command "$command_name"
done

echo "==> Checking repository hygiene"
"$ROOT_DIR/scripts/check_repo_hygiene.sh"

echo "==> Building debug"
swift build

echo "==> Building release"
swift build -c release

echo "==> Packaging release app"
"$ROOT_DIR/scripts/package_app.sh" release

echo "==> Verifying Info.plist"
plutil -lint "$INFO_PLIST"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "==> Verifying bundled icon"
cmp -s "$SOURCE_ICON" "$APP_ICON"

echo "==> Creating release zip"
release_output="$("$ROOT_DIR/scripts/create_release_zip.sh" release)"
ZIP_PATH="$(printf "%s\n" "$release_output" | sed -n "1p")"
CHECKSUM_PATH="$(printf "%s\n" "$release_output" | sed -n "2p")"

echo "==> Verifying release zip checksum"
(
    cd "$(dirname "$CHECKSUM_PATH")"
    shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)

echo "==> Creating release dmg"
dmg_output="$("$ROOT_DIR/scripts/create_release_dmg.sh" release)"
DMG_PATH="$(printf "%s\n" "$dmg_output" | sed -n "1p")"
DMG_CHECKSUM_PATH="$(printf "%s\n" "$dmg_output" | sed -n "2p")"

echo "==> Verifying release dmg"
hdiutil verify "$DMG_PATH" >/dev/null
(
    cd "$(dirname "$DMG_CHECKSUM_PATH")"
    shasum -a 256 -c "$(basename "$DMG_CHECKSUM_PATH")"
)

echo "==> Creating release manifest"
MANIFEST_PATH="$("$ROOT_DIR/scripts/create_release_manifest.sh")"
python3 -m json.tool "$MANIFEST_PATH" >/dev/null

echo "==> Checking obsolete toolbar icon usage"
if rg -q "textformat\\.abc" "$ROOT_DIR/Sources"; then
    echo "Found obsolete textformat.abc toolbar icon usage." >&2
    exit 1
fi

echo "==> Smoke launching release app"
"$ROOT_DIR/scripts/smoke_launch_app.sh"

echo "==> Gatekeeper assessment"
if spctl --assess --type execute --verbose=4 "$APP_DIR"; then
    echo "Gatekeeper assessment passed."
else
    echo "Gatekeeper assessment did not pass. This is expected for local ad-hoc signing before Developer ID notarization."
fi

echo "Release verification complete: $APP_DIR"
