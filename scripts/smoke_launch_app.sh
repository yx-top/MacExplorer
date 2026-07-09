#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacExplorer"
APP_DIR="${1:-${APP_DIR:-$ROOT_DIR/dist/$APP_NAME.app}}"
BUNDLE_ID="local.macexplorer.app"

cd "$ROOT_DIR"

if [[ ! -d "$APP_DIR" ]]; then
    "$ROOT_DIR/scripts/package_app.sh" release >/dev/null
fi

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 0.5

open "$APP_DIR"

pid=""
for _ in {1..30}; do
    pid="$(pgrep -x "$APP_NAME" || true)"
    if [[ -n "$pid" ]]; then
        break
    fi
    sleep 0.2
done

if [[ -z "$pid" ]]; then
    echo "$APP_NAME did not launch within the smoke-test timeout." >&2
    exit 1
fi

sleep 1

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        echo "$APP_NAME launch smoke test passed."
        exit 0
    fi
    sleep 0.2
done

echo "$APP_NAME launched but did not quit cleanly after the smoke test." >&2
exit 1
