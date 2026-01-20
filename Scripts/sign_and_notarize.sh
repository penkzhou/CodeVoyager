#!/usr/bin/env bash
#
# sign_and_notarize.sh - Sign and notarize a DMG for distribution
#
# Usage:
#   ./Scripts/sign_and_notarize.sh <dmg_path>
#
# Required environment variables:
#   APP_IDENTITY              - Developer ID Application certificate name
#                               e.g., "Developer ID Application: Your Name (TEAMID)"
#
# Authentication (one of the following methods):
#
# Method 1 - Keychain profile (recommended for local use):
#   NOTARY_KEYCHAIN_PROFILE   - Name of notarytool credentials stored in keychain
#                               Create with: xcrun notarytool store-credentials
#
# Method 2 - API Key (recommended for CI):
#   APP_STORE_CONNECT_API_KEY_PATH - Path to .p8 API key file
#   APP_STORE_CONNECT_KEY_ID       - API Key ID
#   APP_STORE_CONNECT_ISSUER_ID    - Issuer ID
#
# Optional:
#   NOTARIZE_TIMEOUT          - Timeout in seconds (default: 1800 = 30 minutes)
#
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <dmg_path>" >&2
    exit 1
fi

DMG_PATH="$1"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "ERROR: DMG not found: $DMG_PATH" >&2
    exit 1
fi

# Validate environment
if [[ -z "${APP_IDENTITY:-}" ]]; then
    echo "ERROR: APP_IDENTITY environment variable is required" >&2
    exit 1
fi

NOTARIZE_TIMEOUT=${NOTARIZE_TIMEOUT:-1800}

echo "========================================"
echo "Signing and Notarizing DMG"
echo "========================================"
echo "  DMG: $DMG_PATH"
echo "  Identity: $APP_IDENTITY"
echo ""

# Step 1: Sign the DMG
echo "Step 1: Signing DMG..."
codesign --force --timestamp --sign "$APP_IDENTITY" "$DMG_PATH"

echo "  Verifying signature..."
codesign --verify --verbose "$DMG_PATH"
echo "  ✓ DMG signed successfully"
echo ""

# Step 2: Submit for notarization
echo "Step 2: Submitting for notarization..."

# Build notarytool arguments based on available credentials
NOTARY_ARGS=()

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    # Method 1: Keychain profile
    echo "  Using keychain profile: $NOTARY_KEYCHAIN_PROFILE"
    NOTARY_ARGS+=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
elif [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
    # Method 2: API Key file
    if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}" ]] || [[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
        echo "ERROR: APP_STORE_CONNECT_KEY_ID and APP_STORE_CONNECT_ISSUER_ID are required with API key" >&2
        exit 1
    fi
    echo "  Using API key: $APP_STORE_CONNECT_KEY_ID"
    NOTARY_ARGS+=(
        --key "$APP_STORE_CONNECT_API_KEY_PATH"
        --key-id "$APP_STORE_CONNECT_KEY_ID"
        --issuer "$APP_STORE_CONNECT_ISSUER_ID"
    )
else
    echo "ERROR: No notarization credentials found" >&2
    echo "" >&2
    echo "Please set one of the following:" >&2
    echo "  - NOTARY_KEYCHAIN_PROFILE (for local development)" >&2
    echo "  - APP_STORE_CONNECT_API_KEY_PATH + APP_STORE_CONNECT_KEY_ID + APP_STORE_CONNECT_ISSUER_ID (for CI)" >&2
    exit 1
fi

# Submit and wait for notarization
SUBMISSION_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    "${NOTARY_ARGS[@]}" \
    --wait \
    --timeout "$NOTARIZE_TIMEOUT" \
    2>&1) || {
    echo "ERROR: Notarization submission failed" >&2
    echo "$SUBMISSION_OUTPUT" >&2

    # Try to extract submission ID and get log
    SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
    if [[ -n "$SUBMISSION_ID" ]]; then
        echo "" >&2
        echo "Fetching notarization log for submission: $SUBMISSION_ID" >&2
        xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" 2>&1 || true
    fi
    exit 1
}

echo "$SUBMISSION_OUTPUT"

# Check if notarization was successful
if echo "$SUBMISSION_OUTPUT" | grep -q "status: Accepted"; then
    echo "  ✓ Notarization accepted"
else
    echo "ERROR: Notarization was not accepted" >&2

    # Extract submission ID and fetch log
    SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
    if [[ -n "$SUBMISSION_ID" ]]; then
        echo "" >&2
        echo "Fetching notarization log..." >&2
        xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" 2>&1 || true
    fi
    exit 1
fi
echo ""

# Step 3: Staple the notarization ticket
echo "Step 3: Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"
echo "  ✓ Ticket stapled successfully"
echo ""

# Step 4: Verify the final result
echo "Step 4: Verifying notarized DMG..."
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
echo "  ✓ DMG passes Gatekeeper assessment"
echo ""

# Calculate final checksum
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)

echo "========================================"
echo "Notarization Complete!"
echo "========================================"
echo "  DMG: $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo "  SHA256: $DMG_SHA256"
echo ""
echo "The DMG is now ready for distribution."
