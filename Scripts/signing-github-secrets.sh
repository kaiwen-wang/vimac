#!/usr/bin/env bash
# Print base64 values to paste into GitHub Actions secrets (do not commit output).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/load-signing-env.sh
source "$ROOT/scripts/load-signing-env.sh"

if [ ! -f "$SIGNING_P12" ]; then
  echo "ERROR: Missing $SIGNING_P12"
  echo ""
  echo "Export it from Keychain Access:"
  echo "  My Certificates → Developer ID Application: … → Export → .p12"
  echo "  Save as signing/developer-id.p12"
  exit 1
fi

if [ -z "${P12_PASSWORD+set}" ]; then
  echo "ERROR: Set P12_PASSWORD in signing/.env (use empty value if the .p12 has no password)"
  exit 1
fi

echo "Add these GitHub repository secrets (Settings → Secrets → Actions):"
echo ""
echo "BUILD_CERTIFICATE_BASE64="
base64 < "$SIGNING_P12" | tr -d '\n'
echo ""
echo ""
echo "P12_PASSWORD=$P12_PASSWORD"
echo "KEYCHAIN_PASSWORD=<any random string, e.g. openssl rand -base64 32>"
echo ""

if [ -n "${NOTARY_API_KEY_ID:-}" ] && [ -n "${NOTARY_API_ISSUER_ID:-}" ] && [ -n "${NOTARY_API_KEY_PATH:-}" ] && [ -f "$NOTARY_API_KEY_PATH" ]; then
  echo "NOTARY_API_KEY_ID=$NOTARY_API_KEY_ID"
  echo "NOTARY_API_ISSUER_ID=$NOTARY_API_ISSUER_ID"
  echo "NOTARY_API_KEY_BASE64="
  base64 < "$NOTARY_API_KEY_PATH" | tr -d '\n'
  echo ""
else
  echo "Notary (also set in signing/.env, then re-run):"
  echo "  NOTARY_API_KEY_ID / NOTARY_API_ISSUER_ID / NOTARY_API_KEY_PATH"
fi
