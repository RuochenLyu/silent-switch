#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${SILENT_SWITCH_CODE_SIGN_IDENTITY:-Silent Switch Local Development}"
KEYCHAIN_PATH="${SILENT_SWITCH_KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

if /usr/bin/security find-identity -v -p codesigning "$KEYCHAIN_PATH" | /usr/bin/grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
  echo "$IDENTITY_NAME"
  exit 0
fi

if [[ "${SILENT_SWITCH_CREATE_SELF_SIGNED_IDENTITY:-}" != "1" ]]; then
  cat >&2 <<EOF
error: local self-signed code signing identity does not exist: $IDENTITY_NAME

For normal development, prefer an existing Apple Development identity:
  SILENT_SWITCH_CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make build-debug

To create the local self-signed identity in your login keychain, run:
  SILENT_SWITCH_CREATE_SELF_SIGNED_IDENTITY=1 make setup-signing
EOF
  exit 1
fi

TMP_DIR="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CERT_PATH="$TMP_DIR/local-codesign.cer"
KEY_PATH="$TMP_DIR/local-codesign.key"
P12_PATH="$TMP_DIR/local-codesign.p12"
P12_PASSWORD="$(/usr/bin/uuidgen)"

/usr/bin/openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -days 3650 \
  -keyout "$KEY_PATH" \
  -out "$CERT_PATH" \
  -subj "/CN=$IDENTITY_NAME/" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" >/dev/null 2>&1

/usr/bin/openssl pkcs12 \
  -export \
  -inkey "$KEY_PATH" \
  -in "$CERT_PATH" \
  -name "$IDENTITY_NAME" \
  -out "$P12_PATH" \
  -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

/usr/bin/security import "$P12_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/xcrun >/dev/null

/usr/bin/security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN_PATH" \
  "$CERT_PATH"

if ! /usr/bin/security find-identity -v -p codesigning "$KEYCHAIN_PATH" | /usr/bin/grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
  echo "error: failed to create local code signing identity: $IDENTITY_NAME" >&2
  exit 1
fi

echo "$IDENTITY_NAME"
