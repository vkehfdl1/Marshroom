#!/bin/bash
set -euo pipefail

# Marshroom Release Build + DMG Pipeline
# Usage: ./scripts/build-dmg.sh
#
# Prerequisites:
#   - Xcode with Developer ID certificate installed
#   - App Store Connect API key or Apple ID credentials for notarization
#   - Set NOTARIZE_KEYCHAIN_PROFILE env var (created via: xcrun notarytool store-credentials)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$PROJECT_ROOT/Marshroom/Marshroom.xcodeproj"
SCHEME="Marshroom"
EXPORT_OPTIONS="$PROJECT_ROOT/ExportOptions.plist"

BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/Marshroom.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/Marshroom.app"
DMG_PATH="$BUILD_DIR/Marshroom.dmg"

KEYCHAIN_PROFILE="${NOTARIZE_KEYCHAIN_PROFILE:-marshroom}"

echo "=== Marshroom Release Build ==="
echo ""

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive
echo "[1/5] Building Release archive..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

echo "  Archive created at $ARCHIVE_PATH"

# Step 2: Export signed .app
echo "[2/5] Exporting signed app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -quiet

echo "  App exported to $APP_PATH"

# Verify code signing
echo "  Verifying code signature..."
codesign -dvvv "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Signature"
echo ""

# Step 3: Notarize
echo "[3/5] Submitting for notarization..."
xcrun notarytool submit "$APP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "  Notarization complete"

# Step 4: Staple
echo "[4/5] Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
echo "  Ticket stapled"

# Step 5: Create DMG
echo "[5/5] Creating DMG..."

DMG_TEMP="$BUILD_DIR/dmg_staging"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create \
    -volname "Marshroom" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_TEMP"

echo ""
echo "=== Build Complete ==="
echo "DMG: $DMG_PATH"
echo ""
echo "To verify: spctl --assess --verbose=4 --type execute \"$APP_PATH\""
