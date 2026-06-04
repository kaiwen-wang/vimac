#!/usr/bin/env bash
# Archive, export, notarize, staple, and zip Vimac for GitHub Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f "$ROOT/scripts/load-signing-env.sh" ]; then
  # shellcheck source=scripts/load-signing-env.sh
  source "$ROOT/scripts/load-signing-env.sh"
fi

WORKSPACE="${WORKSPACE:-Vimac.xcworkspace}"
SCHEME="${SCHEME:-Vimac}"
BUILD_DIR="${BUILD_DIR:-build}"
ARCHIVE_PATH="$BUILD_DIR/Vimac.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/Vimac.app"
DIST_DIR="${DIST_DIR:-sparkle-releases}"
TEAM_ID="${TEAM_ID:-5RV873WV4N}"
EXPORT_OPTIONS="$ROOT/Scripts/ExportOptions.plist"

mkdir -p "$DIST_DIR" "$EXPORT_PATH"

find_signing_identity() {
  if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
    echo "$CODE_SIGN_IDENTITY"
    return
  fi
  security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" \
    | head -1 \
    | sed -E 's/^[[:space:]]*[0-9]+\) [A-F0-9]+ "(.+)"$/\1/' || true
}

SIGN_IDENTITY="$(find_signing_identity)"
if [ -z "$SIGN_IDENTITY" ]; then
  echo "ERROR: Developer ID Application certificate required."
  echo "  Local: install the cert from developer.apple.com (or Xcode → Settings → Accounts → Manage Certificates)."
  echo "  CI: set BUILD_CERTIFICATE_BASE64, P12_PASSWORD, and KEYCHAIN_PASSWORD repository secrets."
  exit 1
fi

echo "Using signing identity: $SIGN_IDENTITY"

echo "Archiving $SCHEME (Release, universal macOS)..."
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  BUILD_ENV=CI \
  -allowProvisioningUpdates \
  archive

echo "Exporting Developer ID build..."
rm -rf "$EXPORT_PATH"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

test -d "$APP_PATH"

codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier" || true

NOTARY_ZIP="$DIST_DIR/Vimac-notarize.zip"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"

notarize() {
  if [ -n "${NOTARY_API_KEY_ID:-}" ] && [ -n "${NOTARY_API_ISSUER_ID:-}" ]; then
    : "${NOTARY_API_KEY_BASE64:?Set NOTARY_API_KEY_BASE64 when using App Store Connect API key}"
    local key_dir="$HOME/.appstoreconnect/private_keys"
    local key_file="$key_dir/AuthKey_${NOTARY_API_KEY_ID}.p8"
    mkdir -p "$key_dir"
    echo -n "$NOTARY_API_KEY_BASE64" | base64 --decode > "$key_file"
    chmod 600 "$key_file"
    echo "Submitting to Apple notarization (API key)..."
    xcrun notarytool submit "$NOTARY_ZIP" \
      --key "$key_file" \
      --key-id "$NOTARY_API_KEY_ID" \
      --issuer "$NOTARY_API_ISSUER_ID" \
      --wait
    return
  fi

  if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
    echo "Submitting to Apple notarization (Apple ID)..."
    xcrun notarytool submit "$NOTARY_ZIP" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$TEAM_ID" \
      --wait
    return
  fi

  echo "ERROR: Notarization credentials required."
  echo "  Recommended (CI): NOTARY_API_KEY_ID, NOTARY_API_ISSUER_ID, NOTARY_API_KEY_BASE64"
  echo "  Alternative: APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD"
  exit 1
}

if [ "${SKIP_NOTARIZATION:-}" = "1" ]; then
  echo "SKIP_NOTARIZATION=1 — exporting signed build without notarization."
else
  notarize
  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
fi

ZIP_NAME="${ZIP_NAME:-Vimac-macOS.zip}"
RELEASE_ZIP="$DIST_DIR/$ZIP_NAME"
rm -f "$RELEASE_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$RELEASE_ZIP"
rm -f "$NOTARY_ZIP"

echo "Release artifact: $RELEASE_ZIP"
echo "APP_PATH=$APP_PATH"
echo "RELEASE_ZIP=$RELEASE_ZIP"
