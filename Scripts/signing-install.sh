#!/usr/bin/env bash
# Install Developer ID .cer from signing/ into the login keychain.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/load-signing-env.sh
source "$ROOT/scripts/load-signing-env.sh"

if [ ! -f "$SIGNING_CER" ]; then
  echo "ERROR: Missing $SIGNING_CER"
  echo "Download Developer ID Application from developer.apple.com and save it there."
  exit 1
fi

echo "Installing $SIGNING_CER ..."
if ! security import "$SIGNING_CER" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/security 2>&1; then
  echo "(certificate may already be in keychain — continuing)"
fi

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "OK: Developer ID Application identity is available."
  security find-identity -v -p codesigning | grep "Developer ID Application"
else
  echo "WARNING: .cer installed but no signing identity found."
  echo "The private key must be on this Mac (from the CSR you used). If the CSR was created elsewhere, revoke and recreate the cert."
fi

if [ -f "$SIGNING_P12" ]; then
  if [ -z "${P12_PASSWORD+set}" ]; then
    echo "ERROR: Set P12_PASSWORD in signing/.env (use empty value if the .p12 has no password)"
    exit 1
  fi
  echo "Importing $SIGNING_P12 ..."
  security import "$SIGNING_P12" -P "$P12_PASSWORD" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/security 2>&1 || echo "(.p12 may already be imported — continuing)"
  if [ -n "$P12_PASSWORD" ]; then
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$P12_PASSWORD" ~/Library/Keychains/login.keychain-db 2>/dev/null || true
  fi
fi
