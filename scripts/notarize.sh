#!/bin/bash
set -e

# SpeechDock Notarization Script
# This script notarizes the DMG for distribution
#
# Environment variables:
#   NOTARY_PROFILE  - Keychain profile created with notarytool store-credentials
#   NOTARY_KEYCHAIN - Optional keychain containing that profile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION=$(cat "$PROJECT_DIR/VERSION")
APP_NAME="SpeechDock"
DMG_FILE="$PROJECT_DIR/$APP_NAME-$VERSION.dmg"

echo "Notarizing $APP_NAME v$VERSION..."

# Check environment variables
if [ -z "${NOTARY_PROFILE:-}" ]; then
    echo "Error: Set NOTARY_PROFILE to a stored Keychain profile."
    echo "Create one interactively: xcrun notarytool store-credentials <profile-name>"
    exit 1
fi
AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then
    AUTH_ARGS+=(--keychain "$NOTARY_KEYCHAIN")
fi

# Check if DMG exists
if [ ! -f "$DMG_FILE" ]; then
    echo "Error: $DMG_FILE not found."
    echo "Run ./scripts/create-dmg.sh first."
    exit 1
fi

# Submit for notarization and wait for result
echo "Submitting for notarization..."
# Capture output without letting set -e abort before it can be shown
if ! SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_FILE" \
    "${AUTH_ARGS[@]}" \
    --wait 2>&1); then
    echo "$SUBMIT_OUTPUT"
    echo "Error: notarytool submit failed"
    exit 1
fi

echo "$SUBMIT_OUTPUT"

# Check if notarization was accepted
if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    echo "Notarization accepted!"
else
    echo "Error: Notarization failed"
    exit 1
fi

# Staple the notarization ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_FILE"

# Verify stapling
echo "Verifying stapling..."
xcrun stapler validate "$DMG_FILE"

echo ""
echo "Notarization complete!"
echo "Notarized DMG: $DMG_FILE"
