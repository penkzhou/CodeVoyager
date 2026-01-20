#!/usr/bin/env bash
#
# create_dmg.sh - Create a DMG installer for CodeVoyager
#
# Usage:
#   ./Scripts/create_dmg.sh [app_path]
#
# Arguments:
#   app_path - Path to the .app bundle (default: CodeVoyager.app)
#
# Environment variables:
#   MARKETING_VERSION - Version string (read from version.env if not set)
#   DMG_BACKGROUND    - Path to background image (optional)
#   DMG_WINDOW_WIDTH  - Window width (default: 600)
#   DMG_WINDOW_HEIGHT - Window height (default: 400)
#
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# Load version.env
if [[ -f "$ROOT/version.env" ]]; then
    source "$ROOT/version.env"
fi

APP_NAME=${APP_NAME:-CodeVoyager}
MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}

# Input app bundle
APP_PATH="${1:-${ROOT}/${APP_NAME}.app}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: App bundle not found at: $APP_PATH" >&2
    echo "Run ./Scripts/package_app.sh release first" >&2
    exit 1
fi

# Output DMG name
DMG_NAME="${APP_NAME}-${MARKETING_VERSION}.dmg"
DMG_TEMP="${ROOT}/.build/${APP_NAME}-temp.dmg"
DMG_FINAL="${ROOT}/${DMG_NAME}"

# DMG settings
DMG_VOLUME_NAME="${APP_NAME}"
DMG_WINDOW_WIDTH=${DMG_WINDOW_WIDTH:-600}
DMG_WINDOW_HEIGHT=${DMG_WINDOW_HEIGHT:-400}

echo "Creating DMG for ${APP_NAME} v${MARKETING_VERSION}..."
echo "  Source: ${APP_PATH}"
echo "  Output: ${DMG_FINAL}"

# Create staging directory
STAGING_DIR="${ROOT}/.build/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy app to staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"

# Create temporary DMG (read-write)
rm -f "$DMG_TEMP" "$DMG_FINAL"

# Calculate size needed (app size + 50MB buffer)
APP_SIZE=$(du -sm "$STAGING_DIR" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))

echo "Creating temporary DMG (${DMG_SIZE}MB)..."
hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "$DMG_VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE}m" \
    "$DMG_TEMP"

# Mount the DMG for customization
echo "Mounting DMG for customization..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep -E '^\S+\s+Apple_HFS' | awk '{print $3}')

if [[ -z "$MOUNT_DIR" ]]; then
    echo "ERROR: Failed to mount DMG" >&2
    exit 1
fi

echo "  Mounted at: $MOUNT_DIR"

# Set DMG window appearance using AppleScript
# Note: This may not work in CI environments without a display
if [[ -n "${DISPLAY:-}" ]] || [[ "$(uname)" == "Darwin" && -z "${CI:-}" ]]; then
    echo "Setting DMG window appearance..."
    osascript <<EOF || echo "Note: AppleScript window customization skipped (may require display)"
        tell application "Finder"
            tell disk "${DMG_VOLUME_NAME}"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {100, 100, $((100 + DMG_WINDOW_WIDTH)), $((100 + DMG_WINDOW_HEIGHT))}
                set viewOptions to the icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to 72

                -- Position icons
                set position of item "${APP_NAME}.app" of container window to {150, 200}
                set position of item "Applications" of container window to {450, 200}

                update without registering applications
                close
            end tell
        end tell
EOF
fi

# Ensure all writes are complete
sync

# Unmount
echo "Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR" -force

# Convert to compressed read-only DMG
echo "Creating final compressed DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL"

# Clean up
rm -f "$DMG_TEMP"
rm -rf "$STAGING_DIR"

# Calculate checksum
echo "Calculating checksum..."
DMG_SHA256=$(shasum -a 256 "$DMG_FINAL" | cut -d' ' -f1)

echo ""
echo "========================================"
echo "DMG created successfully!"
echo "========================================"
echo "  File: ${DMG_FINAL}"
echo "  Size: $(du -h "$DMG_FINAL" | cut -f1)"
echo "  SHA256: ${DMG_SHA256}"
echo ""
