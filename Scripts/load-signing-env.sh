#!/usr/bin/env bash
# Load signing/.env for local release commands.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/signing/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

export SIGNING_DIR="${SIGNING_DIR:-$ROOT/signing}"
export SIGNING_P12="${SIGNING_P12:-$SIGNING_DIR/developer-id.p12}"
export SIGNING_CER="${SIGNING_CER:-$SIGNING_DIR/developerID_application.cer}"

if [ -n "${NOTARY_API_KEY_PATH:-}" ] && [ -f "$NOTARY_API_KEY_PATH" ]; then
  export NOTARY_API_KEY_BASE64="$(base64 < "$NOTARY_API_KEY_PATH" | tr -d '\n')"
fi
