#!/bin/bash
set -euo pipefail

# Package with macOS tools only. Signing and notarization follow in
# release-local.sh; this script does not access the signing Keychain.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION=$(cat "$PROJECT_DIR/VERSION")
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="SpeechDock"
APP="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Error: invalid VERSION." >&2
    exit 1
}
for tool in ditto hdiutil; do
    command -v "$tool" >/dev/null || { echo "Error: missing macOS tool $tool." >&2; exit 1; }
done
if [ ! -d "$APP" ]; then
    echo "Error: $APP not found. Build or download the app first." >&2
    exit 1
fi

# Stage only the app and an Applications shortcut. ditto preserves executable
# modes and framework symlinks, as well as the app's existing signatures.
WORK_DIR=$(mktemp -d "$BUILD_DIR/dmg.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT
SOURCE_DIR="$WORK_DIR/volume"
mkdir -p "$SOURCE_DIR"
ditto "$APP" "$SOURCE_DIR/$APP_NAME.app"
ln -s /Applications "$SOURCE_DIR/Applications"

# A failed creation or verification leaves any previous DMG untouched.
# UDZO and HFS+ are supported by all macOS versions supported by this app.
echo "Creating DMG for $APP_NAME v$VERSION with macOS tools..."
hdiutil create -volname "$APP_NAME" -srcfolder "$SOURCE_DIR" \
    -format UDZO -fs HFS+ "$WORK_DIR/$DMG_NAME"
if [ ! -s "$WORK_DIR/$DMG_NAME" ]; then
    echo "Error: DMG creation produced no image." >&2
    exit 1
fi
hdiutil verify "$WORK_DIR/$DMG_NAME"
mv -f "$WORK_DIR/$DMG_NAME" "$PROJECT_DIR/$DMG_NAME"
echo "DMG created: $PROJECT_DIR/$DMG_NAME"
