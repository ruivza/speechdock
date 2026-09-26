#!/bin/bash
set -e

# SpeechDock Notarization Script
# This script notarizes the DMG for distribution
#
# Environment variables:
#   NOTARY_PROFILE - Keychain profile name created via
#                    `xcrun notarytool store-credentials` (recommended;
#                    keeps the app-specific password off the command line)
#
# Fallback when NOTARY_PROFILE is not set:
#   APPLE_ID       - Your Apple ID email
#   TEAM_ID        - Your Apple Developer Team ID
#   APP_PASSWORD   - App-specific password for notarization

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION=$(cat "$PROJECT_DIR/VERSION")
APP_NAME="SpeechDock"
DMG_FILE="$PROJECT_DIR/$APP_NAME-$VERSION.dmg"

echo "Notarizing $APP_NAME v$VERSION..."

# Check environment variables
if [ -n "$NOTARY_PROFILE" ]; then
    # Keychain profile mode: credentials are read from the keychain,
    # so no password appears on the command line
    AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
else
    # Fallback: pass credentials directly (visible to other processes via ps)
    if [ -z "$APPLE_ID" ]; then
        echo "Error: APPLE_ID environment variable is not set"
        exit 1
    fi

    if [ -z "$TEAM_ID" ]; then
        echo "Error: TEAM_ID environment variable is not set"
        exit 1
    fi

    if [ -z "$APP_PASSWORD" ]; then
        echo "Error: APP_PASSWORD environment variable is not set"
        echo "Create an app-specific password at https://appleid.apple.com/"
        echo "Or set up a keychain profile with:"
        echo "  xcrun notarytool store-credentials <profile-name>"
        echo "and set the NOTARY_PROFILE environment variable"
        exit 1
    fi

    AUTH_ARGS=(
        --apple-id "$APPLE_ID"
        --team-id "$TEAM_ID"
        --password "$APP_PASSWORD"
    )
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
