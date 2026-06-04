#!/usr/bin/env bash
# Import Developer ID .p12 into a temporary keychain for CI (GitHub Actions).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_P12="${SIGNING_P12:-$ROOT/signing/developer-id.p12}"

if [ -z "${BUILD_CERTIFICATE_BASE64:-}" ] && [ -f "$SIGNING_P12" ]; then
  BUILD_CERTIFICATE_BASE64="$(base64 < "$SIGNING_P12" | tr -d '\n')"
  if [ -z "${P12_PASSWORD:-}" ] && [ -f "$ROOT/signing/.env" ]; then
    # shellcheck source=scripts/load-signing-env.sh
    source "$ROOT/scripts/load-signing-env.sh"
  fi
fi

: "${BUILD_CERTIFICATE_BASE64:?Set BUILD_CERTIFICATE_BASE64 secret (base64-encoded .p12) or place signing/developer-id.p12}"
if [ -z "${P12_PASSWORD+set}" ]; then
  echo "ERROR: Set P12_PASSWORD secret or signing/.env (empty string if no password)"
  exit 1
fi
: "${KEYCHAIN_PASSWORD:?Set KEYCHAIN_PASSWORD secret (any strong random string)}"

CERTIFICATE_PATH="${RUNNER_TEMP:-/tmp}/build_certificate.p12"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/app-signing.keychain-db"

echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "Installed signing identities:"
security find-identity -v -p codesigning

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "ERROR: No Developer ID Application identity found in imported certificate."
  exit 1
fi
