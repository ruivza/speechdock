#!/bin/bash
set -e

# SpeechDock Build Script
# This script builds the SpeechDock app for release

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION=$(cat "$PROJECT_DIR/VERSION")
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="SpeechDock"

# CI supplies its public Team ID explicitly instead of inheriting an author's
# identity from the generated project. Local builds use Signing.local.xcconfig.
SIGNING_SETTINGS=()
if [ -n "${TEAM_ID:-}" ]; then
    SIGNING_SETTINGS+=("DEVELOPMENT_TEAM=$TEAM_ID")
fi
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    SIGNING_SETTINGS+=("CODE_SIGN_IDENTITY=$SIGNING_IDENTITY")
fi

# Match Rake's allowlist: shell secrets must not enter Xcode build artifacts.
XCODE_ENV=()
for name in PATH HOME USER LOGNAME SHELL TMPDIR TERM LANG LC_ALL LC_CTYPE DEVELOPER_DIR SSH_AUTH_SOCK; do
    if [ "${!name+x}" ]; then
        XCODE_ENV+=("$name=${!name}")
    fi
done

xcode_command() {
    /usr/bin/env -i "${XCODE_ENV[@]}" "$@"
}

echo "Building $APP_NAME v$VERSION..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "Generating Xcode project with XcodeGen..."
    cd "$PROJECT_DIR"
    xcode_command xcodegen generate
else
    echo "XcodeGen not found, using existing project..."
fi

# Check if xcodeproj exists
if [ ! -d "$PROJECT_DIR/$APP_NAME.xcodeproj" ]; then
    echo "Error: $APP_NAME.xcodeproj not found. Please run 'xcodegen generate' first."
    exit 1
fi

# Build the app
echo "Building release version..."
xcode_command xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    "${SIGNING_SETTINGS[@]}" \
    archive

# Export settings are generated in the ignored build directory. Public signing
# selectors can be supplied by CI without changing any tracked configuration.
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
python3 - "$PROJECT_DIR/ExportOptions.plist" "$EXPORT_OPTIONS" "${TEAM_ID:-}" "${SIGNING_IDENTITY:-}" <<'PY'
import plistlib
import sys
from pathlib import Path
options = plistlib.loads(Path(sys.argv[1]).read_bytes())
if sys.argv[3]:
    options["teamID"] = sys.argv[3]
if sys.argv[4]:
    options["signingCertificate"] = sys.argv[4]
Path(sys.argv[2]).write_bytes(plistlib.dumps(options))
PY

# Export the app
echo "Exporting app bundle..."
xcode_command xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

# Verify the app exists
if [ -d "$BUILD_DIR/$APP_NAME.app" ]; then
    echo "Build successful: $BUILD_DIR/$APP_NAME.app"
else
    echo "Error: App bundle not found after export"
    exit 1
fi

echo "Build complete!"
