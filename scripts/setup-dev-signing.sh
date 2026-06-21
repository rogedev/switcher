#!/usr/bin/env bash
# Creates a stable self-signed code-signing identity in a dedicated keychain so local
# dev builds keep a CONSTANT code signature. That lets macOS Accessibility / Screen
# Recording grants persist across rebuilds (ad-hoc signing changes every build, which
# resets those grants). Safe to re-run — it recreates the keychain from scratch.
#
# This identity is for LOCAL DEVELOPMENT ONLY. Distribution builds stay ad-hoc
# (see the Makefile). The keychain password below guards a throwaway self-signed cert
# with no security value.
set -euo pipefail

IDENTITY="Switcher Dev"
KCNAME="switcher-signing.keychain"
KCPASS="switcherdev"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions = v3
prompt = no
[ dn ]
CN = Switcher Dev
O = Switcher
[ v3 ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -days 3650 -config "$WORK/cert.cnf"
# -legacy keeps the PKCS#12 readable by macOS `security` (OpenSSL 3 defaults aren't).
openssl pkcs12 -export -legacy -macalg sha1 \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/switcher.p12" -name "$IDENTITY" -passout pass:"$KCPASS"

security delete-keychain "$KCNAME" 2>/dev/null || true
security create-keychain -p "$KCPASS" "$KCNAME"
security set-keychain-settings "$KCNAME"            # no auto-lock timeout
security unlock-keychain -p "$KCPASS" "$KCNAME"

# Add to the user search list while preserving the existing keychains (incl. login).
ORIG=$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g')
security list-keychains -d user -s "$KCNAME" $ORIG

security import "$WORK/switcher.p12" -k "$KCNAME" -P "$KCPASS" \
  -A -T /usr/bin/codesign -T /usr/bin/security
# Let codesign use the key without a GUI keychain prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KCNAME" >/dev/null

echo "Created signing identity:"
security find-identity -p codesigning "$KCNAME"
